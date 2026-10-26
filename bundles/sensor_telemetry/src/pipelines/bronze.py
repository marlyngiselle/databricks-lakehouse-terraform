"""Bronze: incremental ingestion of landing CSV files with Auto Loader.

Raw values are kept as strings. Nothing is dropped here, so bronze is the
replayable record of exactly what producers sent.
"""

import dlt
from pyspark.sql import functions as F

catalog = spark.conf.get("lakehouse.catalog")  # noqa: F821
landing_path = spark.conf.get("lakehouse.landing_path")  # noqa: F821

RAW_SCHEMA = (
    "device_id STRING, site_id STRING, event_ts STRING, temperature STRING, unit STRING, humidity STRING"
)


@dlt.table(
    name=f"{catalog}.bronze.sensor_readings_raw",
    comment="Sensor readings as received from the landing zone, one row per CSV line.",
    table_properties={"quality": "bronze", "delta.enableChangeDataFeed": "true"},
)
def sensor_readings_raw():
    return (
        spark.readStream.format("cloudFiles")  # noqa: F821
        .option("cloudFiles.format", "csv")
        .option("header", "true")
        .option("cloudFiles.schemaEvolutionMode", "rescue")
        .schema(RAW_SCHEMA)
        .load(landing_path)
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_source_file", F.col("_metadata.file_path"))
    )
