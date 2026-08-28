--- xác định lead cũ / mới

with
lead as (
    select * from {{ ref('hso_lead') }}
),

utm_source as (
    select *
    from {{ source('hh', 'utm_source') }}
    where brand_etl = 4
),

cline as (
    select * from {{ ref('hso_cline') }}
),

view_stag_products as (
    select *
    from {{ source('hh', 'view_stag_products') }}
    where brand_etl = 4
),

payment as (
    select * from {{ ref('hso_payment') }}
),

team_group as (
    select * from {{ source('hh', 'table_team_sale_trans_field') }}
),
company as (
   select * from {{ ref('hso_company') }}
),
stag_sources as (
    select * from {{ source('hh', 'stag_sources') }}
),
ctg_sources as (
    select * from {{ source('hh', 'crm_category_source') }} where brand_etl =4
)
select



    se.employee                                 as create_user,
    ---cl.create_by_department,
    cl.*,
    coalesce(sp.product_category, 'Chưa xác định dịch vụ') as product_category,
    coalesce(sp.product, 'Chưa xác định dịch vụ') as product,
    cl2.*,
    c.name chinhanh,
   --- p.page_name,
  --  sp.his_service_type,
   -- sp.surgery_type,
    rcs.tinh,
    ss.source,
    ep.*
from lead cl
left join {{ref('hso_se')}} se on se.user_id = cl.create_uid
left join company c on c.id =cl.company_id
left join stag_sources ss on ss.old_id =cl.source_id
left join utm_source us on cl.new_source_id = us.id
left join ctg_sources cs on cs.id = us.category_id
left join cline cl2 on cl.id = cl2.crm_id ---and cl2.rnk_line = 1
left join view_stag_products sp on sp.product_id = cl2.product_id
full outer join {{ref('hso_ehc_payment')}} ep on ep.id_booking = cl.lead_booking
left join {{ref('hso_country_state')}} rcs on rcs.id = cl.state_id
