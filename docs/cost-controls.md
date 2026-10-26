# Cost controls

Cost is controlled where it is spent, at cluster creation. Every guardrail below is enforced by the platform, not by a wiki page.

## Cluster policies

| Control | `lakehouse-job-compute` | `lakehouse-interactive-small` |
| --- | --- | --- |
| Cluster type | `job` only | `all-purpose` only |
| Node types | Allow list, `Standard_D4ds_v5` by default | `Standard_D4ds_v5` only |
| Size | Autoscaling, at most `job_max_workers` (8) | At most `interactive_max_workers` (2) |
| Idle shutdown | Not needed, job clusters end with the run | `autotermination_minutes` between 10 and 60, default 30 |
| Clusters per user | Not limited | 1 |
| Capacity | `SPOT_WITH_FALLBACK_AZURE`, hidden from the form | On demand |
| Access mode | `SINGLE_USER` | `USER_ISOLATION` (shared, Unity Catalog enforced) |
| Engine | `PHOTON` by default | Runtime default |

## Forced tags

Both policies and the SQL warehouse stamp the same tags, with `fixed` values that users cannot override.

| Tag | Value | Use |
| --- | --- | --- |
| `CostCenter` | `var.cost_center` | Chargeback in Azure Cost Management |
| `ManagedBy` | `terraform` | Separates governed spend from anything created by hand |
| `Platform` | `var.catalog_prefix` | Groups the lakehouse in cost reports |
| `Workload` | `job`, `interactive` or `sql` | Splits spend by usage pattern |

Databricks propagates cluster tags to the underlying VMs and disks, so the same filter works in the Databricks usage tables and in Azure Cost Management.

## SQL warehouse

| Setting | Value |
| --- | --- |
| Type | `PRO`, serverless when `sql_warehouse_serverless = true` |
| Size | `2X-Small` |
| Scale out | 1 to 2 clusters |
| Auto stop | 5 minutes serverless, 15 minutes classic |

## Pipeline

The medallion pipeline runs serverless and triggered, not continuous. It refreshes once an hour and stops, so nothing idles between runs. The job sets `max_concurrent_runs: 1` and a one hour timeout, and raises an alert when a run exceeds 30 minutes.

## Where to look

1. Azure Cost Management, filtered by tag `Platform = lakehouse` and grouped by `Workload`.
2. The `system.billing.usage` table, joined on `custom_tags`, for per-job and per-warehouse cost.
