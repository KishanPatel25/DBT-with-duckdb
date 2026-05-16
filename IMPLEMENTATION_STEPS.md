# Step-by-Step Implementation: S3 + Fabric + Databricks

Follow these steps in order to set up your multi-source, multi-destination DBT project.

---

## Phase 1: S3 Integration (Start Here)

### Step 1: Get AWS Credentials

1. Log in to **AWS Console**
2. Go to **IAM → Users → Your User**
3. Click **Security Credentials**
4. Create **Access Key** (if you don't have one)
5. Copy:
   - `Access Key ID`
   - `Secret Access Key`

### Step 2: Set Environment Variables (PowerShell)

```powershell
# Open PowerShell as Admin
$env:AWS_ACCESS_KEY_ID = "your-access-key-here"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-key-here"
$env:AWS_REGION = "us-east-1"  # or your region

# Verify they're set
$env:AWS_ACCESS_KEY_ID
$env:AWS_SECRET_ACCESS_KEY
```

### Step 3: Upload Test Parquet to S3

Create a test parquet file locally first:

```python
# In a Python script or Jupyter notebook
import pandas as pd

# Create sample products data
products = pd.DataFrame({
    'product_id': [1, 2, 3, 4],
    'product_name': ['Laptop', 'Mouse', 'Monitor', 'Keyboard'],
    'category': ['Electronics', 'Accessories', 'Electronics', 'Accessories'],
    'price': [999.99, 29.99, 399.99, 79.99],
    'stock_quantity': [50, 200, 75, 150]
})

# Save to parquet
products.to_parquet('products.parquet', index=False)
```

Then upload to S3:
```bash
# Using AWS CLI
aws s3 cp products.parquet s3://your-bucket-name/products/products.parquet
```

### Step 4: Test S3 Read in DuckDB

In PowerShell:
```powershell
cd "c:\Users\KishanPatel\OneDrive - Acres Enterprises\Documents\Programming Projects\101_learn\dbt with duckdb\DBT-with-duckdb"

# Activate venv
.\.venv\Scripts\Activate.ps1

# Test DuckDB connection
python -c "
import duckdb
conn = duckdb.connect('dev.duckdb')
# Install and load S3 extension
conn.execute('INSTALL httpfs')
conn.execute('LOAD httpfs')
# Query S3
result = conn.execute(\"SELECT * FROM read_parquet('s3://your-bucket-name/products/*.parquet')\").fetchall()
print(result)
"
```

### Step 5: Create S3 Model

File: `dbt_with_duckdb/models/stg_products_from_s3.sql`

(Already created for you, just update the S3 path)

```sql
select
    product_id,
    product_name,
    category,
    price,
    stock_quantity,
    current_timestamp() as loaded_at
from read_parquet('s3://YOUR-BUCKET-NAME/products/*.parquet')
```

### Step 6: Test S3 Model

```bash
cd dbt_with_duckdb
dbt run --select stg_products_from_s3 --target dev
```

Expected output: ✅ `PASS` (creates view in DuckDB)

---

## Phase 2: Databricks Integration

### Step 1: Get Databricks Credentials

1. Log in to **Databricks workspace**
2. Click your **Profile icon** (top right)
3. Click **User Settings**
4. Go to **Developer** tab
5. Click **Generate New Token**
6. Copy the **Token** (save securely!)

### Step 2: Get Databricks Connection Details

1. In Databricks, go to **SQL Warehouses**
2. Click your warehouse (or create one)
3. Click **Connection details**
4. Copy:
   - **Server hostname** (host)
   - **HTTP path** (http_path)

Example: `dbc-4c14ed83-f881.cloud.databricks.com` and `/sql/1.0/warehouses/25ae1030ed09636a`

### Step 3: Set Databricks Environment Variables

```powershell
$env:DATABRICKS_HOST = "dbc-abc.cloud.databricks.com"
$env:DATABRICKS_HTTP_PATH = "/sql/1.0/warehouses/xyz123"
$env:DATABRICKS_TOKEN = "dapixxxxx"  # Your token from Step 1
```

### Step 4: Update profiles.yml

```bash
# Open ~/.dbt/profiles.yml
notepad $env:USERPROFILE\.dbt\profiles.yml
```

Add this to your `dbt_with_duckdb` section:

```yaml
dbt_with_duckdb:
  outputs:
    # ... existing dev target ...

    databricks:
      type: databricks
      catalog: 'main'
      schema: 'dbt_learning'
      host: '{{ env_var("DATABRICKS_HOST") }}'
      http_path: '{{ env_var("DATABRICKS_HTTP_PATH") }}'
      token: '{{ env_var("DATABRICKS_TOKEN") }}'
      threads: 4
      timeout_seconds: 300

  target: dev  # Keep dev as default
```

### Step 5: Test Databricks Connection

```bash
dbt debug --target databricks
```

Expected: ✅ All checks pass

### Step 6: Create Test Table in Databricks

In Databricks SQL Editor:

```sql
CREATE TABLE IF NOT EXISTS main.dbt_learning.sales_raw (
    order_id INT,
    customer_id INT,
    order_date DATE,
    order_amount DECIMAL(10, 2),
    currency VARCHAR(3),
    status VARCHAR(50),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

INSERT INTO main.dbt_learning.sales_raw VALUES
(1001, 1, '2024-01-15', 150.50, 'USD', 'completed', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(1002, 2, '2024-01-20', 200.00, 'USD', 'completed', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(1003, 3, '2024-02-01', 75.25, 'USD', 'pending', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
```

### Step 7: Create Databricks Source Model

File: `dbt_with_duckdb/models/stg_sales_from_databricks.sql`

(Already created for you)

### Step 8: Test Databricks Model

```bash
dbt run --select stg_sales_from_databricks --target databricks
```

Expected: ✅ View created in Databricks

---

## Phase 3: Fabric Integration

### Step 1: Create Fabric Lakehouse

1. Log in to **Power BI** (fabric.powerbi.com)
2. Create new **Lakehouse**
3. Name it (e.g., `dbt_analytics`)
4. Get **SQL Endpoint** URL

### Step 2: Get Fabric Connection Details

In Fabric Lakehouse:
1. Click **SQL Endpoint**
2. Copy connection string or:
   - **Server**: From "Connection strings"
   - **Database**: Lakehouse name
   - **Port**: 1433

Example: `workspace-xyz.pbix.fabric.powerbi.com`

### Step 3: Set Fabric Environment Variables

```powershell
$env:FABRIC_SERVER = "workspace-xyz.pbix.fabric.powerbi.com"
$env:FABRIC_DATABASE = "dbt_analytics"
$env:FABRIC_USER = "your-email@company.com"
$env:FABRIC_PASSWORD = "your-password"  # Or use a service principal
```

### Step 4: Update profiles.yml

Add to `~/.dbt/profiles.yml`:

```yaml
dbt_with_duckdb:
  outputs:
    # ... existing targets ...

    fabric:
      type: fabric
      driver: 'ODBC Driver 17 for SQL Server'
      server: '{{ env_var("FABRIC_SERVER") }}'
      database: '{{ env_var("FABRIC_DATABASE") }}'
      schema: dbo
      port: 1433
      username: '{{ env_var("FABRIC_USER") }}'
      password: '{{ env_var("FABRIC_PASSWORD") }}'
      threads: 4

  target: dev
```

### Step 5: Install dbt-fabric Adapter

```bash
pip install dbt-fabric
```

### Step 6: Test Fabric Connection

```bash
dbt debug --target fabric
```

Expected: ✅ All checks pass

### Step 7: Test Fabric Write

```bash
dbt run --select fct_orders --target fabric
```

Check Fabric SQL Editor:
```sql
SELECT * FROM dbo.fct_orders
```

---

## Phase 4: Unified Pipeline

### Step 1: Update dbt_project.yml

Copy content from `DBT_PROJECT_TEMPLATE.yml` to `dbt_with_duckdb/dbt_project.yml`

### Step 2: Organize Models by Layer

Create folder structure:
```
models/
├── staging/
│   ├── stg_customers.sql
│   ├── stg_orders.sql
│   └── stg_products_from_s3.sql
├── intermediate/
│   └── int_orders_with_products.sql
├── marts/
│   └── fct_orders_unified.sql
├── sources.yml
└── schema.yml
```

### Step 3: Update sources.yml

```yaml
version: 2

sources:
  - name: raw_data
    database: memory
    schema: memory
    tables:
      - name: customers
      - name: orders

  - name: s3_products
    database: memory
    schema: memory
    tables:
      - name: products_raw
        external_location: s3://your-bucket/products/

  - name: databricks_analytics
    database: main
    schema: analytics
    tables:
      - name: sales_raw
```

### Step 4: Run All Models to All Targets

```bash
# Development (DuckDB)
dbt run --target dev

# Analytics Warehouse (Fabric)
dbt run --target fabric

# Data Platform (Databricks)
dbt run --target databricks
```

### Step 5: Test Data Quality

```bash
dbt test
```

---

## Phase 5: Validation & Troubleshooting

### Verify S3 Read Works

```bash
dbt run --select stg_products_from_s3 --target dev
```

### Verify Databricks Connection

```bash
dbt run --select stg_sales_from_databricks --target databricks
```

### Verify Fabric Write Works

```bash
dbt run --select fct_orders --target fabric
```

### Check Results Everywhere

**DuckDB:**
```bash
dbt debug  # Shows database path
# Then open with: sqlite3 dev.duckdb "SELECT * FROM fct_orders LIMIT 5;"
```

**Databricks:**
```sql
-- In Databricks SQL Editor
SELECT * FROM main.dbt_learning.fct_orders_unified LIMIT 10
```

**Fabric:**
```sql
-- In Fabric SQL Editor
SELECT * FROM dbo.fct_orders_unified LIMIT 10
```

---

## Quick Reference: Commands by Use Case

### Just Learning (DuckDB only)
```bash
dbt seed
dbt run --target dev
dbt test --target dev
```

### Test Fabric Connection
```bash
dbt run --target fabric
```

### Test Databricks Connection
```bash
dbt run --target databricks
```

### Run All Three in Sequence
```bash
dbt run --target dev && dbt run --target fabric && dbt run --target databricks
```

### Run Specific Model on Specific Target
```bash
dbt run --select stg_products_from_s3 --target dev
dbt run --select fct_orders_unified --target databricks
```

### Generate Documentation
```bash
dbt docs generate
dbt docs serve  # Opens http://localhost:8000
```

---

## Troubleshooting Checklist

### S3 Issues
- [ ] AWS credentials set in environment variables
- [ ] Bucket name is correct
- [ ] Files are parquet format (not CSV)
- [ ] DuckDB httpfs extension loaded

### Databricks Issues
- [ ] Token is valid (check expiration)
- [ ] Server hostname is correct (no /sql/...)
- [ ] HTTP path is complete
- [ ] Schema exists: `main.dbt_learning`

### Fabric Issues
- [ ] ODBC Driver 17 installed (`odbcad32.exe`)
- [ ] Credentials are correct
- [ ] Lakehouse SQL Endpoint is enabled
- [ ] User has write permissions

### General Issues
- [ ] Run `dbt debug` for target you're having issues with
- [ ] Check `.dbt/logs/` for error messages
- [ ] Verify environment variables: `$env:VAR_NAME`
- [ ] Try with `--target dev` first (simplest)

---

## Next: Production Readiness

Once you've tested all three targets, consider:

1. **Incremental Models**: Load only new data
2. **Fact & Dimension Tables**: Design star schema
3. **Data Validation Tests**: Ensure data quality
4. **Documentation**: Keep YAML docs updated
5. **CI/CD Pipeline**: Automate tests + deployments
6. **Monitoring**: Track model run times, row counts

See `S3_FABRIC_DATABRICKS_SETUP.md` for advanced patterns.

Good luck! 🚀
