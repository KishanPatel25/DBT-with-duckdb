-- Read products directly from S3 parquet files
-- Prerequisites:
-- 1. AWS credentials configured in profiles.yml or environment
-- 2. S3 files must be in parquet format
-- 3. Path: s3://your-bucket/products/*.parquet

{{ config(
    materialized='view',
    tags=['s3', 'staging']
) }}

select
    product_id,
    product_name,
    category,
    price,
    stock_quantity,
    _file_name as source_file,
    current_timestamp() as loaded_at
from read_parquet('s3://your-bucket/products/*.parquet')

-- Tips:
-- - Replace 'your-bucket' with your actual S3 bucket
-- - DuckDB automatically handles multiple parquet files matching the pattern
-- - Use view for initial exploration, switch to table if needed
