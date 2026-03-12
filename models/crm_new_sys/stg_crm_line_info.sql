{{ config(materialized='table') }}

with cline_old as (
    select 
        hl.brand_etl, 
        clineo.crm_id as crm_id_old, 
        cline.crm_id, 
        hl.id_old, 
        hl.crm_line_id as clineid, 
        cline.product_id,
        clineo.quantity as quantity_old, 
        clineo.uom_price as uom_price_old, 
        clineo.number_used as number_used_old, 
        clineo.total_before_discount as total_before_discount_old, 
        clineo.total as total_old, 
        clineo.total_received as total_received_old, 
        clineo.stage as stage_old, 
        cline.quantity, 
        cline.number_used, 
        cline.total_before_discount, 
        cline.total, 
        cline.total_received, 
        cline.total_discount, 
        hl.create_date 
    from {{ source('erp', 'crm_sync_crm_line') }} hl
    left join {{ source('erp', 'crm_line') }} cline on hl.crm_line_id = cline.id and hl.brand_etl = cline.brand_etl 
    left join {{ source('erp', 'crm_line') }} clineo on hl.id_old = clineo.id and clineo.brand_etl = 0
),

final as (
    select 
        csb.brand_etl, 
        csb.id_old as crm_id_old, 
        csb.crm_id, 
        cline.id as clineid, 
        cline.product_id, 
        sp.product_category, 
        sp.product, 
        co.quantity_old, 
        co.uom_price_old, 
        co.number_used_old, 
        co.total_before_discount_old, 
        co.total_old, 
        co.total_received_old, 
        co.stage_old, 
        cline.quantity, 
        cline.uom_price, 
        cline.number_used, 
        cline.total_before_discount, 
        cline.total, 
        cline.total_received, 
        cline.stage, 
        csb.create_date, 
        cline.create_date as cline_create_date, 
        cline.create_uid as cline_create_uid 
    from {{ source('erp', 'crm_sync_brand') }} csb
    left join {{ source('erp', 'crm_line') }} cline on csb.crm_id = cline.crm_id and csb.brand_etl = cline.brand_etl 
    left join {{ ref('stg_products') }} sp on cline.product_id = sp.product_id and cline.brand_etl = sp.brand_etl 
    left join cline_old co on cline.id = co.clineid and co.brand_etl = cline.brand_etl 
    where cline.id is not null and cline.stage <> 'cancel'
)

select * from final
