# Governance model

Every privilege in the lakehouse is declared in `infra/unity-catalog` and applied with `databricks_grants`, which is authoritative. A privilege granted by hand in the UI is removed on the next apply, so the code is the only source of truth for who can read what.

## Principals

| Principal | Kind | Workspace role | Purpose |
| --- | --- | --- | --- |
| `platform_admins` | Account group | Admin | Owns every catalog, schema, credential and external location |
| `data_engineers` | Account group | User | Builds pipelines in dev, reads above dev |
| `data_analysts` | Account group | User | Queries curated gold data through the SQL warehouse |
| Pipeline service principal | Service principal | User | Runs test and prod pipelines; the only writer above dev |

## Catalogs and schemas

| Catalog | Schemas | Managed storage root | Isolation |
| --- | --- | --- | --- |
| `lakehouse_dev` | `bronze`, `silver`, `gold` | `abfss://unity-catalog@<account>.dfs.core.windows.net/dev` | Bound to the workspace |
| `lakehouse_test` | `bronze`, `silver`, `gold` | `.../test` | Bound to the workspace |
| `lakehouse_prod` | `bronze`, `silver`, `gold` | `.../prod` | Bound to the workspace |

## Grant matrix

Privilege sets used in the table:

- Read set, `USE_CATALOG`, `USE_SCHEMA`, `BROWSE`, `SELECT`.
- Write set, the read set plus `MODIFY`, `REFRESH`, `CREATE_TABLE`, `CREATE_MATERIALIZED_VIEW`, `CREATE_FUNCTION`, `CREATE_VOLUME`, `READ_VOLUME`, `WRITE_VOLUME`.

| Securable | `platform_admins` | `data_engineers` | `data_analysts` | Pipeline service principal |
| --- | --- | --- | --- | --- |
| `lakehouse_dev` | Owner | Write set | None | None |
| `lakehouse_test` | Owner | Read set | `USE_CATALOG`, `BROWSE` | Write set |
| `lakehouse_prod` | Owner | Read set | `USE_CATALOG`, `BROWSE` | Write set |
| `gold` schema in test and prod | Owner | Inherited read | `USE_SCHEMA`, `SELECT` | Inherited write |
| `bronze` and `silver` in test and prod | Owner | Inherited read | None | Inherited write |
| Landing external location | Owner | `READ_FILES`, `BROWSE` | None | `READ_FILES` |
| Catalog root external locations | Owner | None | None | None |
| Storage credential | Owner, `CREATE_EXTERNAL_LOCATION` | None | None | None |
| SQL warehouse `lakehouse-analytics` | `CAN_MANAGE` | `CAN_USE` | `CAN_USE` | None |
| Policy `lakehouse-job-compute` | Admin | `CAN_USE` | None | `CAN_USE` |
| Policy `lakehouse-interactive-small` | Admin | `CAN_USE` | None | None |

## Principles behind the matrix

1. Ownership is a group, never a person. People leave; `platform_admins` does not.
2. Humans do not write above dev. Test and prod tables change only through a deployed pipeline running as the service principal, which leaves an audit trail tied to a release.
3. Analysts see gold only. Bronze keeps raw payloads and silver keeps row-level detail; neither is a product.
4. Grants are given at the highest level that is still correct. Catalog-level grants inherit to every current and future schema, so a new table needs no grant change.
5. Files and tables are separate. Reading the landing zone needs `READ_FILES` on its external location, which analysts never get.

## Changing a grant

1. Edit `local.catalog_grants` or the relevant `databricks_grants` resource in `infra/unity-catalog`.
2. Open a pull request. CI runs `fmt`, `validate` and `tflint`.
3. The plan shows the exact privilege diff per securable. Review it like code.
4. Apply after merge. Any drift introduced by hand disappears in the same apply.
