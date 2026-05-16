-- Unified fact table combining:
-- - Customers from seeds
-- - Orders from seeds (or could be from Databricks)
-- - Products from S3

{{ config(
    materialized='table',
    tags=['marts', 'core'],
    meta={
        'owner': 'analytics_team',
        'description': 'Unified order facts from multiple sources'
    }
) }}

with customers as (
    select
        customer_id,
        customer_name,
        email,
        signup_date
    from {{ ref('customers') }}
),

orders as (
    select
        order_id,
        customer_id,
        order_date,
        amount,
        status
    from {{ ref('orders') }}
),

products as (
    -- If using S3 source, uncomment:
    -- select * from {{ ref('stg_products_from_s3') }}

    -- For now, use a hardcoded temp table or seed
    select
        1 as product_id,
        'Product A' as product_name,
        'Electronics' as category,
        99.99 as price
    where false  -- Placeholder until S3 is configured
),

final as (
    select
        o.order_id,
        c.customer_id,
        c.customer_name,
        c.email,
        o.order_date,
        o.amount,
        o.status,
        p.product_name,
        p.category,
        p.price,
        current_timestamp() as processed_at
    from orders o
    left join customers c
        on o.customer_id = c.customer_id
    left join products p
        on true  -- Simplified for now; add proper join logic
)

select * from final
