with s as (
    select * from {{ ref('stg_resc_payment_transfer') }}
),
s2 as (
    select * from {{ ref('stg_resc_products') }}
),
m as (
    select * from {{ ref('stg_resc_m_res_company') }}
),
r as (
    select * from {{ ref('stg_resc_res_brand') }}
)
select 
    s.*, 
    s2.product, 
    m."name" as company_ds, 
    r."name" as brand_ds 
from s 
left join s2 on s.product_id = s2.product_id
left join m on m.id = s.company_id and m.brand_etl = s.brand_etl 
left join r on r.id = m.brand_id and m.brand_etl = r.brand_etl
