# ADR 0002. One catalog per environment in a shared metastore

## Status

Accepted

## Context

Azure allows one Unity Catalog metastore per region. Environments still need hard boundaries for data and for privileges, and tables need fully qualified names that do not change between code and environment except for one value.

## Decision

Each environment gets its own catalog (`lakehouse_dev`, `lakehouse_test`, `lakehouse_prod`) with the same three schemas (`bronze`, `silver`, `gold`). Each catalog has its own managed storage root, is `ISOLATED`, and is bound to the workspaces allowed to see it. Code receives the catalog name as a single bundle variable.

## Consequences

- The same SQL runs in every environment with one variable changed.
- Grants differ per environment in one place (`local.catalog_grants`), which makes the least privilege story reviewable in a single file.
- Managed data of each environment sits under its own path, so retention, replication and deletion can differ.
- Cross-environment reads are possible for whoever holds grants on both catalogs. The matrix grants nobody write access in more than one tier.
