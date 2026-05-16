-- Read sales data from Databricks
-- This model only works when running with --target databricks
-- It references a table in your Databricks workspace

-- For other targets (dev, fabric), this will fail gracefully or be skipped

{% if execute and target.name == 'databricks' %}

{{ config(
    materialized='view',
    tags=['databricks', 'staging'],
    database='main',
    schema='analytics'
) }}

select
    order_id,
    customer_id,
    order_date,
    order_amount,
    currency,
    status,
    created_at,
    updated_at
from `main.analytics.sales_raw`
where created_at >= dateadd(day, -90, current_date)

{% else %}

-- Dummy query for non-Databricks targets
{{ config(materialized='view') }}

select 1 as dummy_col where false

{% endif %}

-- Usage:
-- Run with: dbt run --target databricks --select stg_sales_from_databricks
--
-- Table naming convention in Databricks:
-- - `catalog.schema.table` (Unity Catalog)
-- - Most common: `main.analytics.table_name`
