-- Union crm_line và crm_line_product, dùng chung cho dspq và smpq
-- Giữ nguyên logic gốc từ cả 2 file SQL

with line as (
    select
        cl.total_received,
        cl.id,
        cl.crm_id,
        cl.product_id,
        cl.stage,
        cl.create_date,
        cl.brand_etl
    from {{ ref('stg_rtqdk_crm_line') }} cl
    where cl.brand_etl = 1
),

line_product as (
    select
        clp.total_received,
        clp.id,
        clp.booking_id as crm_id,
        clp.product_id,
        clp.stage_line_product as stage,
        clp.create_date,
        clp.brand_etl
    from {{ ref('stg_rtqdk_crm_line_product') }} clp
    where clp.brand_etl = 1
)

select * from line
union all
select * from line_product

