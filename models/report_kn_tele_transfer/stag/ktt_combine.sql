--- xác định lead cũ / mới

with first_headsale as (
    select * from {{ ref('ktt_first_headsale') }}
),

lead as (
    select * from {{ ref('ktt_lead') }}
),

se as (
    select se.*, ct.group_name from {{ ref('ktt_se') }} se
    left join  {{ source('data', 'cs_agents_api') }} ct on se.work_email = ct.email
),

deal as (
    select * from {{ ref('ktt_deal') }}
),

contact as (
    select * from {{ ref('ktt_contact') }}
),

utm_source as (
    select *
    from {{ source('data', 'utm_source') }}
    where brand_etl = 1
),

cline as (
    select * from {{ ref('ktt_cline') }}
),

view_stag_products as (
    select *
    from {{ source('data', 'view_stag_products') }}
    where brand_etl = 1
),

payment as (
    select * from {{ ref('ktt_payment') }}
),

team_group as (
    select * from {{ source('data', 'table_team_sale_trans_field') }}
),
company as (
   select * from {{ ref('ktt_company') }} 
),
stag_sources as (
    select * from {{ source('data', 'stag_sources') }}
),
ctg_sources as (
    select * from {{ source('data', 'crm_category_source') }} where brand_etl =1
)
select
    coalesce(f.ticket_id::text, cl.ticket_id::text, '0')
        || '-' || coalesce(cl.id::text, '0')
        || '-' || coalesce(cl2.id::text, '0')
        || '-' || coalesce(spt.id::text, '0')   as row_key,
    ct.phone_no,
    ct.username,
    dl.id                                       as deal_id,
    us.name                                     as source_new,
    cs.name as ctg_source_new,
    ss.source,
    ss.category_source,
    cl.create_date - f.first_date               as diff_date,
    coalesce(f.first_date, cl.create_date)      as first_date,
   coalesce(f.username ,   se.employee )                              as first_user,
   coalesce( f.group_name, se.group_name) group_name,
   se.group_name group_name_create,
    se.employee                                 as create_user,
    cl.*,
    case
        when lower(f.username) = lower(se.employee)
             and cl.create_date - f.first_date <= 30
        then 'SĐT mới'
        when lower(f.username) = lower(se.employee)
             and cl.create_date - f.first_date > 30
        then 'SĐT cũ'
        when lower(f.username) <> lower(se.employee)
             and cl.create_date > f.first_date
        then 'SĐT cũ'
        when lower(f.username) <> lower(se.employee) --bổ sung thêm cái này
             and cl.create_date = f.first_date
        then 'SĐT mới'
        else 'SĐT mới' --đổi từ khác thành SDT mới
    end                                          as "group_data",
    spt.id                                        as payment_id,
    spt.payment_date,
    spt.payment,
    spt.ma_phieu,
    sp.product_category,
    sp.product,
    cl2.id                                        as line_id,
    cl2.stage,
    cl2.total_received,
    c.name chinhanh,
    p.page_name,
    sp.his_service_type,
    sp.surgery_type,
    rcs.tinh
from first_headsale f
full outer join lead cl on f.ticket_id = cl.ticket_id
left join se on se.user_id = cl.create_uid
left join company c on c.id =cl.company_id
left join deal dl on dl.id = coalesce(f.ticket_id, cl.ticket_id)
left join {{ref('ktt_ad_page')}} p on p.ticket_id = coalesce(f.ticket_id, cl.ticket_id)
left join stag_sources ss on ss.old_id =cl.source_id
left join contact ct on ct.id = dl.requester_id
left join utm_source us on cl.new_source_id = us.id
left join ctg_sources cs on cs.id = us.category_id
left join cline cl2 on cl.id = cl2.crm_id
left join view_stag_products sp on sp.product_id = cl2.product_id
left join payment spt
    on spt.crm_id = cl.id
    and spt.clineid = cl2.id
    and spt.product_id = sp.product_id
left join {{ref('ktt_country_state')}} rcs on rcs.id = cl.state_id
