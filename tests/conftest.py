from __future__ import annotations

import csv
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ROOT = REPO_ROOT / "bundles" / "sensor_telemetry"
SAMPLE_CSV = BUNDLE_ROOT / "fixtures" / "sensor_readings_sample.csv"


@pytest.fixture(scope="session")
def sample_rows() -> list[dict[str, str]]:
    with SAMPLE_CSV.open(newline="") as handle:
        return list(csv.DictReader(handle))
