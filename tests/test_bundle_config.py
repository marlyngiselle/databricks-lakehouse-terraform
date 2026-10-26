"""Static checks of the asset bundle, so a broken YAML never reaches the workspace."""

from __future__ import annotations

from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

BUNDLE = Path(__file__).resolve().parents[1] / "bundles" / "sensor_telemetry"


def _load(path: Path) -> dict:
    with path.open() as handle:
        return yaml.safe_load(handle)


@pytest.fixture(scope="module")
def bundle() -> dict:
    return _load(BUNDLE / "databricks.yml")


@pytest.fixture(scope="module")
def job() -> dict:
    return _load(BUNDLE / "resources" / "sensor_telemetry.job.yml")["resources"]["jobs"]["sensor_telemetry"]


@pytest.fixture(scope="module")
def pipeline() -> dict:
    resources = _load(BUNDLE / "resources" / "sensor_telemetry.pipeline.yml")
    return resources["resources"]["pipelines"]["sensor_telemetry"]


def test_targets_dev_and_prod(bundle: dict) -> None:
    assert set(bundle["targets"]) == {"dev", "prod"}
    assert bundle["targets"]["dev"]["mode"] == "development"
    assert bundle["targets"]["prod"]["mode"] == "production"


def test_prod_runs_as_service_principal(bundle: dict) -> None:
    assert "service_principal_name" in bundle["targets"]["prod"]["run_as"]


def test_schedule_only_unpaused_in_prod(bundle: dict, job: dict) -> None:
    assert bundle["variables"]["schedule_pause_status"]["default"] == "PAUSED"
    assert bundle["targets"]["prod"]["variables"]["schedule_pause_status"] == "UNPAUSED"
    assert job["schedule"]["pause_status"] == "${var.schedule_pause_status}"


def test_job_alerts_on_failure_and_duration(job: dict) -> None:
    assert job["email_notifications"]["on_failure"]
    assert job["health"]["rules"][0]["metric"] == "RUN_DURATION_SECONDS"


def test_job_cluster_uses_policy(job: dict) -> None:
    for cluster in job["job_clusters"]:
        assert cluster["new_cluster"]["policy_id"] == "${var.job_policy_id}"


def test_pipeline_libraries_exist(pipeline: dict) -> None:
    for library in pipeline["libraries"]:
        path = (BUNDLE / "resources" / library["file"]["path"]).resolve()
        assert path.is_file(), path


def test_spark_python_task_file_exists(job: dict) -> None:
    for task in job["tasks"]:
        if "spark_python_task" in task:
            path = (BUNDLE / "resources" / task["spark_python_task"]["python_file"]).resolve()
            assert path.is_file(), path
