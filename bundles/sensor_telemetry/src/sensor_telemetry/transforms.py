"""Pure functions for sensor telemetry.

Every rule here has a twin in `spark_transforms` or in the pipeline expectations,
so the behaviour can be tested in milliseconds without a cluster.
"""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

# Physical bounds of the reference sensor. Anything outside is a faulty reading,
# not an anomaly, and is dropped in silver.
TEMPERATURE_RANGE_C = (-40.0, 125.0)
HUMIDITY_RANGE_PCT = (0.0, 100.0)

# Operating band. Readings outside it are kept but flagged as anomalies in gold.
OPERATING_RANGE_C = (5.0, 85.0)

SUPPORTED_UNITS = frozenset({"C", "F"})

# Silver expectations, written once as SQL and reused by the pipeline.
SILVER_EXPECTATIONS: dict[str, str] = {
    "valid_device_id": "device_id IS NOT NULL AND length(device_id) > 0",
    "valid_timestamp": "event_ts IS NOT NULL",
    "temperature_in_sensor_range": (
        "temperature_c IS NOT NULL AND "
        f"temperature_c BETWEEN {TEMPERATURE_RANGE_C[0]} AND {TEMPERATURE_RANGE_C[1]}"
    ),
    "humidity_in_range": (
        f"humidity_pct IS NULL OR humidity_pct BETWEEN {HUMIDITY_RANGE_PCT[0]} AND {HUMIDITY_RANGE_PCT[1]}"
    ),
}


@dataclass(frozen=True)
class Reading:
    """A clean, validated reading as stored in silver."""

    device_id: str
    site_id: str
    event_ts: datetime
    temperature_c: float
    humidity_pct: float | None


@dataclass(frozen=True)
class HourlyAggregate:
    """One row of the gold hourly table."""

    device_id: str
    site_id: str
    window_start: datetime
    reading_count: int
    temperature_min_c: float
    temperature_max_c: float
    temperature_avg_c: float
    humidity_avg_pct: float | None
    anomaly_count: int


def normalize_device_id(raw: str | None) -> str | None:
    """Trim and lowercase a device ID. Empty values become None."""
    if raw is None:
        return None
    cleaned = raw.strip().lower()
    return cleaned or None


def to_celsius(value: float, unit: str) -> float:
    """Convert a temperature to Celsius, rounded to two decimals."""
    unit = unit.strip().upper()
    if unit not in SUPPORTED_UNITS:
        raise ValueError(f"unsupported temperature unit: {unit!r}")
    celsius = value if unit == "C" else (value - 32.0) * 5.0 / 9.0
    return round(celsius, 2)


def parse_timestamp(raw: str | None) -> datetime | None:
    """Parse an ISO 8601 timestamp into an aware UTC datetime.

    Naive timestamps are assumed to be UTC. Unparseable values return None so
    the expectation `valid_timestamp` drops the row instead of failing the run.
    """
    if raw is None or not raw.strip():
        return None
    text = raw.strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def _parse_float(raw: object) -> float | None:
    if raw is None:
        return None
    if isinstance(raw, int | float):
        return float(raw)
    text = str(raw).strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def quality_violations(
    device_id: str | None,
    event_ts: datetime | None,
    temperature_c: float | None,
    humidity_pct: float | None,
) -> list[str]:
    """Return the names of the silver expectations a reading breaks."""
    violations: list[str] = []
    if not device_id:
        violations.append("valid_device_id")
    if event_ts is None:
        violations.append("valid_timestamp")
    low, high = TEMPERATURE_RANGE_C
    if temperature_c is None or not low <= temperature_c <= high:
        violations.append("temperature_in_sensor_range")
    h_low, h_high = HUMIDITY_RANGE_PCT
    if humidity_pct is not None and not h_low <= humidity_pct <= h_high:
        violations.append("humidity_in_range")
    return violations


def clean_record(record: Mapping[str, object]) -> Reading | None:
    """Turn a raw bronze record into a silver Reading, or None if it is rejected."""
    device_id = normalize_device_id(_as_str(record.get("device_id")))
    site_id = normalize_device_id(_as_str(record.get("site_id"))) or "unknown"
    event_ts = parse_timestamp(_as_str(record.get("event_ts")))

    raw_temperature = _parse_float(record.get("temperature"))
    unit = _as_str(record.get("unit")) or "C"
    try:
        temperature_c = None if raw_temperature is None else to_celsius(raw_temperature, unit)
    except ValueError:
        temperature_c = None

    humidity_pct = _parse_float(record.get("humidity"))

    if quality_violations(device_id, event_ts, temperature_c, humidity_pct):
        return None
    # The checks above guarantee these are set; the asserts narrow the types.
    assert device_id is not None and event_ts is not None and temperature_c is not None
    return Reading(device_id, site_id, event_ts, temperature_c, humidity_pct)


def _as_str(value: object) -> str | None:
    return None if value is None else str(value)


def is_anomaly(temperature_c: float, operating_range: tuple[float, float] = OPERATING_RANGE_C) -> bool:
    """A reading outside the operating band, but inside the sensor's physical range."""
    low, high = operating_range
    return not low <= temperature_c <= high


def hour_window(ts: datetime) -> datetime:
    """Floor a timestamp to the start of its hour."""
    return ts.replace(minute=0, second=0, microsecond=0)


def deduplicate(readings: Iterable[Reading]) -> list[Reading]:
    """Keep one reading per device and timestamp: the last one seen wins."""
    latest: dict[tuple[str, datetime], Reading] = {}
    for reading in readings:
        latest[(reading.device_id, reading.event_ts)] = reading
    return sorted(latest.values(), key=lambda r: (r.device_id, r.event_ts))


def aggregate_hourly(readings: Iterable[Reading]) -> list[HourlyAggregate]:
    """Build the gold hourly table: one row per device and hour."""
    groups: dict[tuple[str, str, datetime], list[Reading]] = defaultdict(list)
    for reading in readings:
        groups[(reading.device_id, reading.site_id, hour_window(reading.event_ts))].append(reading)

    rows: list[HourlyAggregate] = []
    for (device_id, site_id, window_start), items in sorted(groups.items()):
        temperatures = [r.temperature_c for r in items]
        humidities = [r.humidity_pct for r in items if r.humidity_pct is not None]
        rows.append(
            HourlyAggregate(
                device_id=device_id,
                site_id=site_id,
                window_start=window_start,
                reading_count=len(items),
                temperature_min_c=min(temperatures),
                temperature_max_c=max(temperatures),
                temperature_avg_c=round(sum(temperatures) / len(temperatures), 2),
                humidity_avg_pct=round(sum(humidities) / len(humidities), 2) if humidities else None,
                anomaly_count=sum(1 for t in temperatures if is_anomaly(t)),
            )
        )
    return rows


def is_fresh(latest: datetime | None, now: datetime, max_lag: timedelta) -> bool:
    """True when the newest gold window is recent enough to trust."""
    if latest is None:
        return False
    return now - latest <= max_lag
