# Quick Reference: S3 + Fabric + Databricks Commands

## Environment Setup (Do Once)

```powershell
# PowerShell - set environment variables
$env:AWS_ACCESS_KEY_ID = "your-aws-key"
$env:AWS_SECRET_ACCESS_KEY = "your-aws-secret"
$env:AWS_REGION = "us-east-1"

$env:DATABRICKS_HOST = "dbc-xxx.cloud.databricks.com"
$env:DATABRICKS_HTTP_PATH = "/sql/1.0/warehouses/xxx"
$env:DATABRICKS_TOKEN = "dapixxx"

$env:FABRIC_SERVER = "workspace.pbix.fabric.powerbi.com"
$env:FABRIC_DATABASE = "my_lakehouse"
$env:FABRIC_USER = "email@company.com"
$env:FABRIC_PASSWORD = "password"
```

## Running DBT by Target

### DuckDB (Local Development)
```bash
# Default target
dbt run
dbt test
dbt run --target dev

# Also: dbt docs serve (http://localhost:8000)
```

### Fabric (Analytics Warehouse)
```bash
dbt run --target fabric
dbt test --target fabric
```

### Databricks (Data Platform)
```bash
dbt run --target databricks
dbt test --target databricks
```

### All Three
```bash
dbt run --target dev && dbt run --target fabric && dbt run --target databricks
```

## Common Operations

| Task | Command |
|------|---------|
| Load CSV seeds | `dbt seed` |
| Run all models | `dbt run` |
| Run specific model | `dbt run --select model_name` |
| Run tag-based | `dbt run --select tag:staging` |
| Test data quality | `dbt test` |
| Check connection | `dbt debug --target <target>` |
| Generate docs | `dbt docs generate && dbt docs serve` |
| Clean up | `dbt clean` |

## Sources by Target

| Source | Target | Syntax |
|--------|--------|--------|
| Seeds (CSV) | DuckDB | `{{ ref('customers') }}` |
| S3 Parquet | DuckDB | `read_parquet('s3://bucket/...')` |
| Databricks Table | Databricks | `` `catalog.schema.table` `` |
| Local View | All | `{{ ref('model_name') }}` |

## Model Locations

```
models/
├── staging/          # Raw data transformations
│   ├── stg_customers.sql
│   ├── stg_orders.sql
│   └── stg_products_from_s3.sql
├── intermediate/     # Business logic
│   └── int_orders_with_products.sql
├── marts/            # Final output tables
│   └── fct_orders_unified.sql
├── sources.yml       # Data source definitions
└── schema.yml        # Output table documentation
```

## Verify Each Target

### DuckDB
```bash
dbt run --target dev
# Check: dev.duckdb file (SQLite format)
```

### Databricks
```bash
dbt run --target databricks
# Check: main.dbt_learning.* tables in Databricks SQL Editor
```

### Fabric
```bash
dbt run --target fabric
# Check: dbo.* tables in Fabric SQL Editor
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| S3 won't read | Check AWS credentials, bucket name, file format (must be parquet) |
| Databricks fail | Verify token, host, http_path with `dbt debug --target databricks` |
| Fabric connection error | Ensure ODBC Driver 17 installed, credentials correct |
| "target not found" | Update profiles.yml in ~/.dbt/ |
| Models not building | Check file format (*.sql), model syntax, logs in target/ |

## Model Organization by Complexity

### Beginner
```
models/
├── stg_customers.sql (from seed)
├── stg_orders.sql (from seed)
└── fct_orders.sql (join customers + orders)
```

### Intermediate
```
models/
├── staging/
│   ├── stg_customers.sql
│   ├── stg_orders.sql
│   └── stg_products_from_s3.sql
├── marts/
│   └── fct_orders.sql
└── schema.yml
```

### Advanced
```
models/
├── staging/
│   └── (raw data transformations)
├── intermediate/
│   └── (business logic, joins)
├── marts/
│   ├── dim_customers.sql (dimensions)
│   └── fct_orders.sql (facts)
├── sources.yml (data lineage)
├── schema.yml (documentation + tests)
└── tests/ (custom tests)
```

## Performance Tips

- **S3 reads**: Parquet > CSV (columnar format)
- **Staging models**: Keep as views (faster iteration)
- **Marts models**: Use tables (persist for analytics)
- **Databricks**: Use Unity Catalog for governance
- **Fabric**: Use SQL Endpoint for OLAP queries
- **Tests**: Run on marts only (catch errors early)

## Next Learning Steps

1. ✅ Set up all three targets
2. ⬜ Create 5-10 models across staging/intermediate/marts
3. ⬜ Add data quality tests (unique, not_null, relationships)
4. ⬜ Document with YAML schemas
5. ⬜ Create incremental models (load only new data)
6. ⬜ Set up CI/CD pipeline (GitHub Actions, etc.)

Good luck! 🚀
