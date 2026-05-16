# Architecture: S3 + Databricks → DuckDB + Fabric + Databricks

## Data Pipeline Visualization

```
┌──────────────────────────────────────────────────────────────────┐
│                          DATA SOURCES                             │
├──────────────────┬──────────────────────────┬────────────────────┤
│  Seeds (CSV)     │  S3 (Parquet)            │  Databricks Tables │
│  - customers.csv │  - s3://bucket/products/ │  - main.analytics  │
│  - orders.csv    │  - (raw data)            │  - (raw data)      │
└────────┬─────────┴──────────┬───────────────┴────────┬───────────┘
         │                    │                        │
         │                    │                        │
         └────────┬───────────┴────────┬───────────────┘
                  │                    │
            ┌─────▼────────────────────▼─────┐
            │    DBT Transformations         │
            │   (SQL Models)                 │
            │                               │
            │  1. Staging Layer (Views)     │
            │     - stg_customers           │
            │     - stg_orders              │
            │     - stg_products_from_s3    │
            │     - stg_sales_from_db       │
            │                               │
            │  2. Intermediate (Tables)     │
            │     - int_orders_with_products│
            │                               │
            │  3. Marts (Facts/Dimensions)  │
            │     - fct_orders_unified      │
            │     - dim_customers (future)  │
            └─────┬───────────────────┬─────┘
                  │                   │
                  │                   │
      ┌───────────▼────────┬──────────▼──────────┬──────────────────┐
      │  DuckDB            │  Fabric Warehouse   │  Databricks      │
      │  (dev.duckdb)      │  (Analytics)        │  (Data Platform) │
      │                    │                     │                  │
      │  ✓ Models: views   │  ✓ Models: tables   │  ✓ Models:       │
      │  ✓ Fast iteration  │  ✓ Query tool       │    tables        │
      │  ✓ Local testing   │  ✓ BI integration   │  ✓ Computation   │
      │  ✓ No scaling      │  ✓ Multi-user       │  ✓ ML workloads  │
      │                    │  ✓ Fine-grained     │  ✓ Data sharing  │
      │                    │    access control   │                  │
      └────────────────────┴─────────────────────┴──────────────────┘
```

## Execution Flow (with Commands)

```
┌─────────────────────────────────────────┐
│ 1. Set Environment Variables            │
│    (AWS, Databricks, Fabric creds)      │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 2. Load Seeds (CSV → DuckDB)            │
│    $ dbt seed                           │
│    → customers.csv → duckdb table       │
│    → orders.csv → duckdb table          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 3. Run Models Locally (DuckDB)          │
│    $ dbt run --target dev               │
│    → Staging views created              │
│    → Mart tables created                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 4. Test Data Quality                    │
│    $ dbt test --target dev              │
│    → Validates unique keys              │
│    → Checks not_null constraints        │
└──────────────┬──────────────────────────┘
               │
       ┌───────┼───────┐
       │       │       │
       ▼       ▼       ▼
    ┌──────┬──────┬──────┐
    │ Sync │ Sync │ Sync │
    │to    │to    │to    │
    │Duck  │Fab   │DB    │
    │DB    │ric   │      │
    └──────┴──────┴──────┘
```

## By Target: What Happens

### Target: `dev` (DuckDB)
```
CSV Seeds → DuckDB (dev.duckdb)
S3 Parquet → DuckDB (via httpfs)
           ↓
        Models
           ↓
     Local tables/views
     
Command: dbt run --target dev
```

### Target: `databricks` (Databricks Warehouse)
```
Databricks Tables (main.analytics) → Models
                                      ↓
                              Databricks Tables
                              (main.dbt_learning)
                              
Command: dbt run --target databricks
```

### Target: `fabric` (Fabric Warehouse)
```
Models (from all sources)
    ↓
Fabric Warehouse (dbo.*)
    ↓
Power BI Reports
BI Analytics

Command: dbt run --target fabric
```

## File Structure

```
dbt_with_duckdb/
├── dbt_project.yml              # Project config (paths, materialization)
├── seeds/
│   ├── customers.csv            # Seed data
│   └── orders.csv               # Seed data
├── models/
│   ├── staging/
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_products_from_s3.sql       # Reads S3
│   │   └── stg_sales_from_databricks.sql  # Reads Databricks
│   ├── intermediate/
│   │   └── int_orders_with_products.sql
│   ├── marts/
│   │   └── fct_orders_unified.sql
│   ├── sources.yml              # Define data sources
│   ├── schema.yml               # Document models + tests
│   └── docs.md                  # Entity docs (future)
├── macros/
│   └── setup_s3.sql             # S3 initialization helper
├── tests/                       # Custom tests (future)
└── analyses/                    # Ad-hoc queries (future)

~/.dbt/
└── profiles.yml                 # Credentials (dev/databricks/fabric)
```

## Which Target for What?

| Use Case | Target | Why |
|----------|--------|-----|
| Learn DBT | `dev` | Fast, local, free, no setup needed |
| Read from S3 | `dev` | DuckDB has native S3 support |
| Read from Databricks | `databricks` | Direct access to tables |
| Analytics Dashboard | `fabric` | Power BI integration, multi-user |
| Data Science | `databricks` | Python, ML models, compute power |
| Production Export | All three | Replicate data across systems |

## Materialization Strategy

| Layer | Materialization | Target |
|-------|-----------------|--------|
| Staging | View | All (minimal overhead) |
| Intermediate | Table | Databricks + Fabric |
| Marts | Table | Databricks + Fabric |

**Why?**
- Views are cheap (stored logic, not data)
- Tables persist data (faster for downstream queries)
- DuckDB: views OK since it's ephemeral
- Fabric/Databricks: tables needed for long-term access

## Environment Credentials Map

```
Local Machine Environment Variables
    │
    ├─→ AWS_* → S3 Access (DuckDB reads)
    │
    ├─→ DATABRICKS_* → Databricks (read/write)
    │
    └─→ FABRIC_* → Fabric (write)

     ↓
     
~/.dbt/profiles.yml (reads from env vars)
     │
     ├─→ output: dev → DuckDB
     │
     ├─→ output: databricks → Databricks Warehouse
     │
     └─→ output: fabric → Fabric Warehouse
```

## Data Lineage Example

```
For model: fct_orders_unified

Input                  Transform           Output
─────                  ─────────           ──────

customers.csv ─┐
               ├─→ stg_customers ─┐
                                   ├─→ fct_orders_unified ─┐
orders.csv ────→ stg_orders ──────┤                         ├─→ [All 3 targets]
                                   └─→ int_orders_* ───────┘
s3://products/*.parquet ──→ stg_products_from_s3 ──┘

main.analytics.sales_raw ──→ stg_sales_from_databricks ──┘
```

Lineage command:
```bash
dbt docs generate && dbt docs serve
# View in browser: http://localhost:8000
# Click graph icon to see lineage
```

## Best Practices

### Development
1. Work in `dev` target (fast feedback loop)
2. Use views for staging (easy to recompile)
3. Test locally before pushing to Fabric/Databricks

### Testing
1. Run tests after each model: `dbt test`
2. Add data quality tests in schema.yml
3. Validate row counts, nulls, uniqueness

### Documentation
1. Document sources in sources.yml
2. Document models in schema.yml
3. Add column descriptions + tests
4. Generate docs: `dbt docs generate`

### Production
1. Use Databricks + Fabric as production targets
2. Schedule daily/hourly runs
3. Monitor logs and metrics
4. Version control: commit to git

---

## Next: Try It!

**Quick start:**
```bash
cd dbt_with_duckdb

# 1. Test local dev
dbt seed
dbt run --target dev
dbt test --target dev

# 2. Test Databricks (if configured)
dbt debug --target databricks
dbt run --select stg_sales_from_databricks --target databricks

# 3. Test Fabric (if configured)
dbt debug --target fabric
dbt run --select fct_orders --target fabric

# 4. View everything
dbt docs generate && dbt docs serve
```

See **IMPLEMENTATION_STEPS.md** for detailed walkthrough! 🚀
