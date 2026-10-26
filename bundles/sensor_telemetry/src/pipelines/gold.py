"""Gold: hourly device statistics for analysts and dashboards."""

import sys

import dlt

# The bundle passes its src folder so shared modules import the same way here as in tests.
sys.path.append(spark.conf.get("bundle.sourcePath"))  # noqa: F821

from sensor_telemetry.spark_transforms import hourly_aggregates

catalog = spark.conf.get("lakehouse.catalog")  # noqa: F821


@dlt.table(
    name=f"{catalog}.gold.sensor_hourly_stats",
    comment="One row per device and hour: counts, temperature statistics and anomalies.",
    table_properties={"quality": "gold"},
)
@dlt.expect_or_fail("positive_count", "reading_count > 0")
def sensor_hourly_stats():
    return hourly_aggregates(spark.read.table(f"{catalog}.silver.sensor_readings"))  # noqa: F821
