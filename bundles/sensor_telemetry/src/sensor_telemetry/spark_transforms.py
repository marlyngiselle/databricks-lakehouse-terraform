"""Spark versions of the silver and gold rules.

Imported by the pipeline and by the optional Spark tests. Kept free of
pipeline decorators so it can run on a local SparkSession.
"""

from __future__ import annotations

from pyspark.sql import Column, DataFrame
from pyspark.sql import functions as F

from sensor_telemetry.transforms import OPERATING_RANGE_C


def _temperature_c(value: Column, unit: Column) -> Column:
    upper_unit = F.upper(F.trim(F.coalesce(unit, F.lit("C"))))
    celsius = (
        F.when(upper_unit == "C", value)
        .when(upper_unit == "F", (value - F.lit(32.0)) * F.lit(5.0) / F.lit(9.0))
        .otherwise(F.lit(None).cast("double"))
    )
    return F.round(celsius, 2)


def clean_readings(raw: DataFrame) -> DataFrame:
    """Normalize types and units. Rejection is left to the pipeline expectations.

    try_cast and try_to_timestamp turn malformed values into nulls instead of
    failing the update under ANSI mode, so the expectations can count them.
    """
    device_id = F.lower(F.trim(F.col("device_id")))
    site_id = F.lower(F.trim(F.col("site_id")))
    return raw.select(
        F.when(F.length(device_id) > 0, device_id).alias("device_id"),
        F.coalesce(F.when(F.length(site_id) > 0, site_id), F.lit("unknown")).alias("site_id"),
        F.expr("try_to_timestamp(event_ts)").alias("event_ts"),
        _temperature_c(F.expr("try_cast(temperature AS DOUBLE)"), F.col("unit")).alias("temperature_c"),
        F.expr("try_cast(humidity AS DOUBLE)").alias("humidity_pct"),
    )


def deduplicate(readings: DataFrame) -> DataFrame:
    """One row per device and timestamp."""
    return readings.dropDuplicates(["device_id", "event_ts"])


def hourly_aggregates(readings: DataFrame) -> DataFrame:
    """Gold table: one row per device, site and hour."""
    low, high = OPERATING_RANGE_C
    anomaly = (~F.col("temperature_c").between(low, high)).cast("int")
    return readings.groupBy(
        "device_id",
        "site_id",
        F.date_trunc("hour", F.col("event_ts")).alias("window_start"),
    ).agg(
        F.count(F.lit(1)).alias("reading_count"),
        F.min("temperature_c").alias("temperature_min_c"),
        F.max("temperature_c").alias("temperature_max_c"),
        F.round(F.avg("temperature_c"), 2).alias("temperature_avg_c"),
        F.round(F.avg("humidity_pct"), 2).alias("humidity_avg_pct"),
        F.sum(anomaly).alias("anomaly_count"),
    )
