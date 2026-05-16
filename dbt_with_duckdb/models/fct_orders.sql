{{ config(
    materialized='table'
) }}

select
    o.order_id,
    o.customer_id,
    c.customer_name,
    o.order_date,
    o.amount,
    o.status
from {{ ref('orders') }} o
join {{ ref('customers') }} c
    on o.customer_id = c.customer_id
