"""Fail the job when the gold table is stale, so the failure alert fires."""

from __future__ import annotations

import argparse
import os
import sys
from datetime import UTC, datetime, timedelta

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from sensor_telemetry.transforms import is_fresh


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--max-lag-minutes", type=int, default=90)
    args = parser.parse_args(argv)

    from pyspark.sql import SparkSession

    spark = SparkSession.builder.getOrCreate()
    table = f"{args.catalog}.gold.sensor_hourly_stats"
    latest = spark.sql(f"SELECT max(window_start) AS latest FROM {table}").first()["latest"]
    if latest is not None and latest.tzinfo is None:
        latest = latest.replace(tzinfo=UTC)

    now = datetime.now(UTC)
    max_lag = timedelta(minutes=args.max_lag_minutes)
    if not is_fresh(latest, now, max_lag):
        print(f"STALE: newest window in {table} is {latest}, allowed lag {max_lag}")
        return 1
    print(f"FRESH: newest window in {table} is {latest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
