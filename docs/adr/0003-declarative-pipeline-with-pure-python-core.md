# ADR 0003. Declarative pipeline with a pure Python core

## Status

Accepted

## Context

Pipeline notebooks are hard to test. They need a cluster, they mix I/O with logic, and their quality rules live in decorators that only run inside the pipeline runtime.

## Decision

The medallion flow is a Lakeflow declarative pipeline (Delta Live Tables) deployed by an asset bundle. The pipeline files only wire sources, targets and expectations. The rules live in `sensor_telemetry.transforms` as pure Python, with a Spark twin in `sensor_telemetry.spark_transforms`. The silver expectations are a single dictionary of SQL predicates, used by the pipeline and asserted by the tests.

## Consequences

- The core tests run in under a second with no Spark and no cloud account.
- The Spark tests run wherever a JDK is present, CI included, and skip cleanly elsewhere.
- A rule change shows up in one function and one test, not in a notebook diff.
- The pipeline runtime still owns orchestration, retries, lineage and expectation metrics, which are not reimplemented.
