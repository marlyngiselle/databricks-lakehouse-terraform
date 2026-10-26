from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from sensor_telemetry.transforms import (
    SILVER_EXPECTATIONS,
    Reading,
    aggregate_hourly,
    clean_record,
    deduplicate,
    hour_window,
    is_anomaly,
    is_fresh,
    normalize_device_id,
    parse_timestamp,
    quality_violations,
    to_celsius,
)

TS = datetime(2026, 1, 15, 8, 30, tzinfo=UTC)


def _record(**overrides: object) -> dict[str, object]:
    record: dict[str, object] = {
        "device_id": "sensor-001",
        "site_id": "site-a",
        "event_ts": "2026-01-15T08:30:00Z",
        "temperature": "21.5",
        "unit": "C",
        "humidity": "40.0",
    }
    record.update(overrides)
    return record


@pytest.mark.parametrize(
    ("raw", "expected"),
    [(" SENSOR-001 ", "sensor-001"), ("sensor-002", "sensor-002"), ("   ", None), (None, None)],
)
def test_normalize_device_id(raw: str | None, expected: str | None) -> None:
    assert normalize_device_id(raw) == expected


@pytest.mark.parametrize(
    ("value", "unit", "expected"),
    [(21.5, "C", 21.5), (32.0, "F", 0.0), (212.0, "f", 100.0), (-40.0, "F", -40.0)],
)
def test_to_celsius(value: float, unit: str, expected: float) -> None:
    assert to_celsius(value, unit) == expected


def test_to_celsius_rejects_unknown_unit() -> None:
    with pytest.raises(ValueError, match="unsupported"):
        to_celsius(300.0, "K")


def test_parse_timestamp_handles_zulu_offsets_and_naive() -> None:
    assert parse_timestamp("2026-01-15T08:30:00Z") == TS
    assert parse_timestamp("2026-01-15T09:30:00+01:00") == TS
    assert parse_timestamp("2026-01-15T08:30:00") == TS


@pytest.mark.parametrize("raw", ["not-a-timestamp", "", None])
def test_parse_timestamp_returns_none_on_garbage(raw: str | None) -> None:
    assert parse_timestamp(raw) is None


def test_clean_record_accepts_valid_reading() -> None:
    reading = clean_record(_record())
    assert reading == Reading("sensor-001", "site-a", TS, 21.5, 40.0)


def test_clean_record_converts_fahrenheit_and_defaults_site() -> None:
    reading = clean_record(_record(temperature="71.6", unit="F", site_id=""))
    assert reading is not None
    assert reading.temperature_c == 22.0
    assert reading.site_id == "unknown"


def test_clean_record_keeps_missing_humidity() -> None:
    reading = clean_record(_record(humidity=""))
    assert reading is not None
    assert reading.humidity_pct is None


@pytest.mark.parametrize(
    "overrides",
    [
        {"device_id": ""},
        {"event_ts": "yesterday"},
        {"temperature": "180"},
        {"temperature": "abc"},
        {"unit": "K"},
        {"humidity": "130"},
    ],
)
def test_clean_record_rejects_bad_readings(overrides: dict[str, object]) -> None:
    assert clean_record(_record(**overrides)) is None


def test_quality_violations_names_match_pipeline_expectations() -> None:
    violations = quality_violations(None, None, None, 150.0)
    assert set(violations) == set(SILVER_EXPECTATIONS)


def test_quality_violations_empty_for_valid_values() -> None:
    assert quality_violations("sensor-001", TS, 20.0, 50.0) == []


@pytest.mark.parametrize(
    ("temperature", "expected"), [(4.9, True), (5.0, False), (85.0, False), (91.5, True)]
)
def test_is_anomaly(temperature: float, expected: bool) -> None:
    assert is_anomaly(temperature) is expected


def test_hour_window_floors_to_the_hour() -> None:
    assert hour_window(datetime(2026, 1, 15, 8, 59, 59, 999, tzinfo=UTC)) == datetime(
        2026, 1, 15, 8, tzinfo=UTC
    )


def test_deduplicate_keeps_last_reading_per_key() -> None:
    first = Reading("sensor-001", "site-a", TS, 20.0, None)
    second = Reading("sensor-001", "site-a", TS, 22.0, None)
    other = Reading("sensor-002", "site-a", TS, 23.0, None)
    assert deduplicate([first, other, second]) == [second, other]


def test_aggregate_hourly_computes_stats_and_anomalies() -> None:
    readings = [
        Reading("sensor-001", "site-a", TS, 20.0, 40.0),
        Reading("sensor-001", "site-a", TS + timedelta(minutes=10), 24.0, None),
        Reading("sensor-001", "site-a", TS + timedelta(minutes=20), 90.0, 50.0),
        Reading("sensor-001", "site-a", TS + timedelta(hours=1), 21.0, None),
    ]
    first_hour, second_hour = aggregate_hourly(readings)

    assert first_hour.window_start == datetime(2026, 1, 15, 8, tzinfo=UTC)
    assert first_hour.reading_count == 3
    assert (first_hour.temperature_min_c, first_hour.temperature_max_c) == (20.0, 90.0)
    assert first_hour.temperature_avg_c == 44.67
    assert first_hour.humidity_avg_pct == 45.0
    assert first_hour.anomaly_count == 1

    assert second_hour.reading_count == 1
    assert second_hour.humidity_avg_pct is None
    assert second_hour.anomaly_count == 0


def test_is_fresh() -> None:
    now = datetime(2026, 1, 15, 10, 0, tzinfo=UTC)
    lag = timedelta(minutes=90)
    assert is_fresh(now - timedelta(minutes=60), now, lag)
    assert not is_fresh(now - timedelta(minutes=120), now, lag)
    assert not is_fresh(None, now, lag)
