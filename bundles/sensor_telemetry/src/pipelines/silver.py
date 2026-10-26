"""Silver: typed, unit-normalized, deduplicated readings with enforced expectations."""

import sys

import dlt

# The bundle passes its src folder so shared modules import the same way here as in tests.
sys.path.append(spark.conf.get("bundle.sourcePath"))  # noqa: F821

from sensor_telemetry.spark_transforms import clean_readings, deduplicate
from sensor_telemetry.transforms import SILVER_EXPECTATIONS

catalog = spark.conf.get("lakehouse.catalog")  # noqa: F821


@dlt.table(
    name=f"{catalog}.silver.sensor_readings",
    comment="Validated sensor readings in Celsius. Rows breaking an expectation are dropped and counted.",
    table_properties={"quality": "silver"},
    cluster_by=["device_id"],
)
@dlt.expect_all_or_drop(SILVER_EXPECTATIONS)
def sensor_readings():
    raw = spark.readStream.table(f"{catalog}.bronze.sensor_readings_raw")  # noqa: F821
    return deduplicate(clean_readings(raw).withWatermark("event_ts", "2 hours"))
