-- CRM Line đã dedup cross brand_etl (0 cũ, 1 mới, sync, + crm_line_product)
select cl.id, cl.crm_id, cl.product_id, cl.stage, cl.create_date, cl.brand_etl
from {{ source('rmkd', 'crm_line') }} cl
where cl.brand_etl = 0 and brand_id = 1
  and not exists (select 1 from {{ source('rmkd', 'crm_line') }} x where x.brand_etl = 1 and x.id = cl.id)
  and not exists (select 1 from {{ source('rmkd', 'crm_sync_brand') }} x where x.brand_etl = 3 and x.id_old = cl.id)

union all

select cl.id, cl.crm_id, cl.product_id, cl.stage, cl.create_date, cl.brand_etl
from {{ source('rmkd', 'crm_line') }} cl
where cl.brand_etl = 1 and cl.create_date < '20250801'

union all

select cl3.id, cl3.crm_id, cl2.product_id, cl3.stage, cl2.create_date, csl.brand_etl
from {{ source('rmkd', 'crm_sync_crm_line') }} csl
left join {{ source('rmkd', 'crm_line') }} cl2 on cl2.id = csl.id_old and cl2.brand_etl = 0
left join {{ source('rmkd', 'crm_line') }} cl3 on cl3.id = csl.crm_line_id and csl.brand_etl = cl3.brand_etl
where csl.brand_etl = 1

union all

select cl.id, cl.crm_id, cl.product_id, cl.stage, cl.create_date, cl.brand_etl
from {{ source('rmkd', 'crm_line') }} cl
where cl.brand_etl = 1 and cl.create_date >= '20250801'
  and not exists (select 1 from {{ source('rmkd', 'crm_sync_crm_line') }} x where x.brand_etl = 1 and x.crm_line_id = cl.id)

union all

select id, booking_id, product_id, stage_line_product, create_date, brand_etl
from {{ source('rmkd', 'crm_line_product') }}
where brand_etl in (0, 1)

