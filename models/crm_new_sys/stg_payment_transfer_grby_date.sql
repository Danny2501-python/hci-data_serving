{{ config(materialized='table') }}

with base as (
    select * from {{ ref('stg_payment_transfer') }}
),

aggregated as (
    select
        brand_id,
        crm_id,
        product_id,
        payment_date,
        string_agg(id, ',') as ids,
        string_agg(ma_phieu, ',') as ma_phieus,
        string_agg(clineid::varchar, ',') as clineids,
        string_agg(payment_type, ',') as payment_types,
        sum(payment) as total_payment,
        max(quantity) as quantity,
        max(uom_price) as uom_price,
        max(number_used) as number_used,
        max(total) as total,
        max(total_received_cline) as total_received_cline,
        max(total_received_cumsum) as total_received_cumsum,
        max(stage_product) as stage_product,
        max(orgcompany_id) as orgcompany_id,
        max(brand_etl) as brand_etl
    from base
    group by 1, 2, 3, 4
)

select * from aggregated
