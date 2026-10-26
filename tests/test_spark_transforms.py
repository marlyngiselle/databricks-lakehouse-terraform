"""Spark twins of the pure rules. Skipped unless pyspark and a JVM are available."""

from __future__ import annotations

import pytest

pyspark = pytest.importorskip("pyspark")

from sensor_telemetry.transforms import SILVER_EXPECTATIONS  # noqa: E402

pytestmark = pytest.mark.spark


@pytest.fixture(scope="module")
def spark():
    from pyspark.sql import SparkSession

    try:
        session = (
            SparkSession.builder.master("local[1]")
            .appName("sensor-telemetry-tests")
            .config("spark.sql.session.timeZone", "UTC")
            .config("spark.ui.enabled", "false")
            .getOrCreate()
        )
    except Exception as exc:  # pragma: no cover - depends on the local JVM
        pytest.skip(f"no usable local Spark: {exc}")
    yield session
    session.stop()


def _silver(spark, rows: list[dict[str, str]]):
    from sensor_telemetry.spark_transforms import clean_readings, deduplicate

    raw = spark.createDataFrame(rows)
    cleaned = clean_readings(raw)
    passing = " AND ".join(f"({rule})" for rule in SILVER_EXPECTATIONS.values())
    return deduplicate(cleaned.where(passing))


def test_spark_silver_matches_pure_pipeline(spark, sample_rows) -> None:
    assert _silver(spark, sample_rows).count() == 25


def test_spark_gold_matches_pure_pipeline(spark, sample_rows) -> None:
    from sensor_telemetry.spark_transforms import hourly_aggregates

    gold = hourly_aggregates(_silver(spark, sample_rows)).collect()
    assert len(gold) == 6
    assert sum(row.anomaly_count for row in gold) == 1
