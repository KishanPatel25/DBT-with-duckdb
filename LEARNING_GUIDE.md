# DBT with DuckDB - Learning Guide

This is a prototype project to learn DBT with DuckDB for local development, reading from S3, and eventually writing to Fabric.

## Project Architecture

```
DuckDB (Local Compute)
    ↓
    ├─ Loads Seeds (CSV) → Quick start data
    ├─ Reads S3 Parquet → Future source
    ↓
    Models (SQL transformations)
    ↓
    Output Tables → Write to Fabric Warehouse (future)
```

## Getting Started

### 1. Load Seeds (CSV files)
```bash
dbt seed
```
This loads `seeds/customers.csv` and `seeds/orders.csv` into DuckDB.

### 2. Run Models
```bash
dbt run
```
This executes `models/fct_orders.sql` which joins customers and orders.

### 3. Test Your Models
```bash
dbt test
```
Validates data quality (unique keys, not null constraints).

### 4. Generate Documentation
```bash
dbt docs generate
dbt docs serve
```

## Project Structure

- **seeds/** - Static CSV data for learning (replaces S3 initially)
- **models/** - SQL transformations (staged models, fact tables)
  - `fct_orders.sql` - Example fact table with join
  - `sources.yml` - Define data sources (seeds, S3, etc.)
  - `schema.yml` - Document output tables and tests
- **tests/** - Data quality tests (custom tests)
- **macros/** - Reusable SQL/Python (custom functions)
- **analyses/** - Ad-hoc analysis (not built by dbt run)

## Next Steps

### Phase 1: Master Seeds & Models (Current)
- ✅ Create seed files
- ✅ Create first transformation model
- ⬜ Add more models (staging, intermediate, fact)
- ⬜ Write tests

### Phase 2: Add S3 Integration
When ready, read Parquet from S3:
```sql
-- In a model, reference S3 parquet directly:
select * from read_parquet('s3://your-bucket/product_data/*.parquet')
```

Configure S3 credentials in DuckDB:
```sql
-- Run this before querying S3:
INSTALL httpfs;
LOAD httpfs;
SET secret (
  TYPE S3,
  KEY_ID 'your-aws-key',
  SECRET 'your-aws-secret',
  REGION 'us-east-1'
);
```

### Phase 3: Write to Fabric
Two approaches:

**Option A: Direct ODBC (DuckDB → Fabric)**
- Install dbt-fabric adapter
- Update profiles.yml with Fabric credentials
- Run `dbt run --profiles-dir ~/.dbt --target fabric`

**Option B: Export from DuckDB, then Load**
```sql
-- Export DuckDB table to CSV/Parquet
COPY (SELECT * FROM fct_orders) TO 'output.parquet'
```
Then load via Fabric's data ingestion.

## Quick Commands

```bash
# Activate virtual environment
source .venv/bin/activate  # Linux/Mac
.venv\Scripts\Activate.ps1  # Windows PowerShell

# Basic dbt commands
dbt debug              # Verify connection to DuckDB
dbt run                # Run all models
dbt test               # Test data quality
dbt run --select fct_orders  # Run specific model
dbt run --profiles-dir ~/.dbt --target prod  # Use prod database

# Clean up
dbt clean              # Remove target/ and dbt_packages/
```

## Learning Tips

1. **Start simple**: Seeds → single model → joins → tests
2. **Use schema.yml**: Document everything for better understanding
3. **Check DuckDB directly**: 
   ```bash
   dbt debug  # Gets the database path
   sqlite3 dev.duckdb "SELECT * FROM customers LIMIT 5;"
   ```
4. **Read the dbt docs**: https://docs.getdbt.com
5. **Explore S3 in DuckDB**: DuckDB has native S3 support, easier than Spark/Hadoop

## Files to Know

- `dbt_project.yml` - Project config (name, paths, materialization rules)
- `~/.dbt/profiles.yml` - Credentials (DuckDB paths, Fabric connection)
- `seeds/*.csv` - Static data
- `models/*.sql` - Your transformations
- `models/*.yml` - Schema documentation

Happy learning! 🚀
