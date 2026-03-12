{{ config(materialized='table') }}

with consults as (
    -- Tư vấn viên Dòng Dịch vụ
    select 
        'service' as data_union, cic.brand_etl, 
        cic.id::varchar as id_raw,
        cic.role, cic.user_id, cline.crm_id, cic.crm_line_id,
        cline.stage, 
        cic.create_date + interval '7 hours' as create_date,
        cic.write_date + interval '7 hours' as write_date
    from {{ source('erp', 'crm_information_consultant') }} cic
    left join {{ source('erp', 'crm_line') }} cline on cic.crm_line_id = cline.id and cline.brand_etl = cic.brand_etl 
    where cic.brand_etl = 3 and cic.crm_line_id is not null 

    union all

    -- Tư vấn viên Dòng Sản phẩm
    select 
        'cosmetic' as data_union, cic.brand_etl, 
        cic.id::varchar as id_raw,
        cic.role, cic.user_id, clp.booking_id as crm_id, cic.crm_line_product_id as crm_line_id,
        clp.stage_line_product as stage, 
        cic.create_date + interval '7 hours' as create_date,
        cic.write_date + interval '7 hours' as write_date
    from {{ source('erp', 'crm_information_consultant') }} cic
    left join {{ source('erp', 'crm_line_product') }} clp on cic.crm_line_product_id = clp.id and clp.brand_etl = cic.brand_etl 
    where cic.brand_etl = 3 and cic.crm_line_product_id is not null
)

select 
    *,
    row_number() over (partition by crm_id, crm_line_id, role order by create_date) as rn_role_line
from consults
where crm_id is not null
