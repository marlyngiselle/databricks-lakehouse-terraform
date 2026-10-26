"""Runs the sample CSV through the pure pipeline and checks the outcome end to end."""

from __future__ import annotations

from sensor_telemetry.transforms import aggregate_hourly, clean_record, deduplicate


def test_sample_file_shape(sample_rows: list[dict[str, str]]) -> None:
    assert len(sample_rows) == 31
    assert set(sample_rows[0]) == {"device_id", "site_id", "event_ts", "temperature", "unit", "humidity"}


def test_silver_drops_exactly_the_defective_rows(sample_rows: list[dict[str, str]]) -> None:
    cleaned = [clean_record(row) for row in sample_rows]
    accepted = [reading for reading in cleaned if reading is not None]

    assert len(sample_rows) - len(accepted) == 5
    assert len(deduplicate(accepted)) == 25


def test_gold_has_one_row_per_device_and_hour(sample_rows: list[dict[str, str]]) -> None:
    readings = deduplicate(r for r in (clean_record(row) for row in sample_rows) if r is not None)
    gold = aggregate_hourly(readings)

    assert len(gold) == 6
    assert sum(row.reading_count for row in gold) == 25
    anomalies = {
        (row.device_id, row.window_start.hour): row.anomaly_count for row in gold if row.anomaly_count
    }
    assert anomalies == {("sensor-001", 9): 1}


def test_fahrenheit_sensor_lands_in_celsius(sample_rows: list[dict[str, str]]) -> None:
    readings = [r for r in (clean_record(row) for row in sample_rows) if r is not None]
    site_b = [r.temperature_c for r in readings if r.device_id == "sensor-003"]
    assert site_b
    assert all(15.0 < t < 30.0 for t in site_b)
