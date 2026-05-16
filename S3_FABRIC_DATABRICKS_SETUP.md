# Multi-Source, Multi-Destination DBT Setup

Configure DBT to read from **S3 + Databricks** and write to **DuckDB + Fabric + Databricks**.

## Architecture

```
┌─────────────┐
│ S3 Parquet  │
└──────┬──────┘
       │
       ├─→ DuckDB (local compute)
       │
       ├─→ Databricks (compute + warehouse)
       │
┌──────┴──────┐
│ Databricks  │
└─────────────┘

       ↓
       
       Models (dbt run)
       
       ↓
       
   ┌───┴───┬─────────┬──────────┐
   ▼       ▼         ▼          ▼
DuckDB  Fabric  Databricks   (S3?)
```

---

## 1. Configure S3 Access in DuckDB

### Step 1a: Install DuckDB S3 Extension

Add this to `macros/setup_s3.sql`:

```sql
-- Initialize S3 support in DuckDB
INSTALL httpfs;
LOAD httpfs;
```

### Step 1b: Set AWS Credentials

**Option A: Via profiles.yml (recommended for learning)**

Update `~/.dbt/profiles.yml`:

```yaml
dbt_with_duckdb:
  outputs:
    dev:
      type: duckdb
      path: dev.duckdb
      threads: 1
      # DuckDB-specific S3 configuration
      s3_region: 'us-east-1'
      s3_access_key_id: '{{ env_var("AWS_ACCESS_KEY_ID") }}'
      s3_secret_access_key: '{{ env_var("AWS_SECRET_ACCESS_KEY") }}'
```

**Option B: Environment Variables (secure)**

Set before running dbt:
```bash
$env:AWS_ACCESS_KEY_ID = "your-access-key"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-key"
$env:AWS_REGION = "us-east-1"
```

**Option C: In SQL (for testing)**

```sql
-- Run this once, DuckDB caches it
INSTALL httpfs;
LOAD httpfs;
CREATE SECRET (
    TYPE S3,
    KEY_ID 'your-aws-key',
    SECRET 'your-aws-secret',
    REGION 'us-east-1'
);
```

### Step 1c: Create a Model to Read S3 Parquet

Create `models/stg_products_from_s3.sql`:

```sql
{{ config(
    materialized='view'
) }}

select
    product_id,
    product_name,
    category,
    price,
    _file_name,
    current_timestamp() as loaded_at
from read_parquet('s3://your-bucket/products/*.parquet')
```

**S3 Path Patterns:**
- Single file: `s3://bucket/path/file.parquet`
- Multiple files: `s3://bucket/path/*.parquet`
- Prefix: `s3://bucket/prefix/` (reads all files)

---

## 2. Configure Fabric as a Write Destination

### Step 2a: Install dbt-fabric Adapter

```bash
pip install dbt-fabric
```

### Step 2b: Update profiles.yml with Fabric Config

```yaml
dbt_with_duckdb:
  outputs:
    dev:
      type: duckdb
      path: dev.duckdb
      threads: 1
      
    fabric:
      type: fabric
      driver: 'ODBC Driver 17 for SQL Server'
      server: '<workspace-id>.pbix.fabric.powerbi.com'
      database: '<lakehouse-name>'
      schema: 'default'
      port: 1433
      username: '{{ env_var("FABRIC_USER") }}'
      password: '{{ env_var("FABRIC_PASSWORD") }}'
      threads: 4
      
  target: dev
```

### Step 2c: Get Fabric Connection Details

1. Open your **Fabric workspace**
2. Go to **Lakehouse** → **SQL Endpoint**
3. Copy connection string:
   - **Server**: `<workspace>.pbix.fabric.powerbi.com`
   - **Database**: `<lakehouse_name>`
   - **Port**: `1433`

### Step 2d: Configure Environment Variables

```bash
# PowerShell
$env:FABRIC_USER = "your-email@company.com"
$env:FABRIC_PASSWORD = "your-password-or-token"
```

### Step 2e: Run Models to Fabric

```bash
dbt run --profiles-dir ~/.dbt --target fabric
```

---

## 3. Configure Databricks as Source + Destination

### Step 3a: Install dbt-databricks Adapter

```bash
pip install dbt-databricks
```

### Step 3b: Update profiles.yml with Databricks

```yaml
dbt_with_duckdb:
  outputs:
    dev:
      type: duckdb
      path: dev.duckdb
      threads: 1
      
    databricks:
      type: databricks
      catalog: 'main'
      schema: 'dbt_learning'
      host: 'dbc-4c14ed83-f881.cloud.databricks.com'  # From your workspace
      http_path: '/sql/1.0/warehouses/your-warehouse-id'
      token: '{{ env_var("DATABRICKS_TOKEN") }}'
      threads: 4
      
  target: dev
```

### Step 3c: Get Databricks Connection Details

1. In **Databricks workspace** → **Admin Settings** → **User Settings**
2. Click **Generate token** (personal access token)
3. Get **Host**: `Settings` → `Workspace URL`
4. Get **HTTP Path**: `SQL Warehouses` → `Connection details`

### Step 3d: Read from Databricks

Create `models/stg_sales_from_databricks.sql`:

```sql
{{ config(
    materialized='view'
) }}

-- Reference a Databricks table directly
select
    order_id,
    customer_id,
    order_amount,
    order_date
from `main.analytics.sales_raw`
```

### Step 3e: Write to Databricks

```bash
dbt run --profiles-dir ~/.dbt --target databricks
```

---

## 4. Multi-Target Strategy

### Scenario: Read from S3 + Databricks, Write to All Three

**Step 1: Create source definitions**

Create `models/sources.yml`:

```yaml
version: 2

sources:
  - name: s3_data
    description: Raw data from S3
    database: memory
    schema: memory
    tables:
      - name: products_raw
        description: Product catalog from S3
        external_location: s3://your-bucket/products/

  - name: databricks_analytics
    description: Analytics tables in Databricks
    database: main
    schema: analytics
    tables:
      - name: sales_raw
        description: Raw sales data from Databricks

  - name: local_seeds
    database: memory
    schema: memory
    tables:
      - name: customers
```

**Step 2: Create models that reference all sources**

Create `models/fct_unified_orders.sql`:

```sql
{{ config(
    materialized='table',
    meta={
        'owner': 'analytics_team',
        'description': 'Unified orders from S3, Databricks, and seeds'
    }
) }}

with customers as (
    select * from {{ ref('customers') }}
),

products as (
    select * from {{ source('s3_data', 'products_raw') }}
),

sales as (
    select * from {{ source('databricks_analytics', 'sales_raw') }}
)

select
    s.order_id,
    c.customer_id,
    c.customer_name,
    p.product_name,
    s.order_amount,
    s.order_date,
    current_timestamp() as processed_at
from sales s
left join customers c on s.customer_id = c.customer_id
left join products p on s.product_id = p.product_id
```

**Step 3: Configure project-level materialization rules**

Update `dbt_project.yml`:

```yaml
name: 'dbt_with_duckdb'
version: '1.0.0'
profile: 'dbt_with_duckdb'

model-paths: ["models"]
seed-paths: ["seeds"]

models:
  dbt_with_duckdb:
    # Default: all views
    +materialized: view
    
    # Override for specific models
    staging:
      +materialized: view        # Keep staging as views
      
    marts:
      +materialized: table       # Build mart tables
      
    # Per-target overrides
    # Run different materializations per target
```

**Step 4: Run to specific targets**

```bash
# Write to DuckDB only
dbt run --profiles-dir ~/.dbt --target dev

# Write to Fabric
dbt run --profiles-dir ~/.dbt --target fabric

# Write to Databricks
dbt run --profiles-dir ~/.dbt --target databricks

# Run all targets sequentially
dbt run --target dev && dbt run --target fabric && dbt run --target databricks
```

---

## 5. Environment Setup (.env or PowerShell)

Create `.env` file (or set in PowerShell):

```bash
# AWS S3
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
AWS_REGION=us-east-1

# Fabric
FABRIC_USER=your-email@company.com
FABRIC_PASSWORD=your-password

# Databricks
DATABRICKS_TOKEN=dapi1234567890abcdef
DATABRICKS_HOST=dbc-4c14ed83-f881.cloud.databricks.com
DATABRICKS_HTTP_PATH=/sql/1.0/warehouses/abc123def456
```

Load in PowerShell:
```powershell
# Load .env variables
Get-Content .env | ForEach-Object {
    if ($_ -match '^\w+') {
        $key, $value = $_ -split '=', 2
        [Environment]::SetEnvironmentVariable($key, $value)
    }
}
```

---

## 6. Testing the Setup

### Test S3 Access
```bash
dbt run --select stg_products_from_s3
```

### Test Databricks Read
```bash
dbt run --select stg_sales_from_databricks
```

### Test Fabric Write
```bash
dbt run --target fabric
```

### Check Fabric Results
```sql
-- In Fabric SQL Editor
SELECT TOP 10 * FROM fct_unified_orders
```

### Check Databricks Results
```sql
-- In Databricks notebook
SELECT * FROM main.dbt_learning.fct_unified_orders LIMIT 10
```

---

## 7. Troubleshooting

### S3 Connection Issues
```bash
# Test S3 in DuckDB directly
dbt run-operation s3_test_connection

# Or manually:
dbt debug
```

### Fabric Connection Issues
```bash
# Check ODBC driver
odbcad32.exe  # Windows: open ODBC Data Source Administrator

# Test connection
dbt debug --target fabric
```

### Databricks Connection Issues
```bash
# Verify token validity
curl -H "Authorization: Bearer $env:DATABRICKS_TOKEN" \
  https://$env:DATABRICKS_HOST/api/2.0/clusters/list

# Test dbt connection
dbt debug --target databricks
```

---

## 8. Quick Reference: Command Cheatsheet

```bash
# Seed + Run DuckDB
dbt seed && dbt run --target dev

# Run all targets
dbt run --target dev && dbt run --target fabric && dbt run --target databricks

# Run specific model on specific target
dbt run --select fct_orders --target databricks

# Test data quality
dbt test --target fabric

# Generate docs
dbt docs generate && dbt docs serve

# Clean up
dbt clean
```

---

## 9. Important Notes

### Data Direction Best Practices
- **S3 → Models**: S3 is read-only (source), not output
- **DuckDB**: Local development (ephemeral, not for production)
- **Databricks**: Can be both source and destination
- **Fabric**: Primary warehouse (destination for final outputs)

### Performance Considerations
- **S3 reads**: Use `parquet` format (columnar, faster)
- **Databricks**: Use Unity Catalog for better governance
- **Fabric**: Use SQL Endpoint for analytics workloads

### Security
- Never commit AWS keys, Databricks tokens, or Fabric passwords
- Use environment variables and secrets management
- For production: use IAM roles, managed identities, OAuth tokens

---

## Next: Try It Step-by-Step

1. **Set AWS credentials** (for S3 access)
2. **Create S3 test model** (`stg_products_from_s3.sql`)
3. **Update profiles.yml** with all three targets
4. **Run locally first**: `dbt run --target dev`
5. **Then to Fabric**: `dbt run --target fabric`
6. **Finally to Databricks**: `dbt run --target databricks`

Good luck! Let me know if you hit any snags. 🚀
