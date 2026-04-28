-- ECL: CRM Lead đã dedup cross brand_etl (0 cũ, 1 mới, sync)
select cl.ticket_id, cl.overseas_vietnamese as vk, cl.contact_name, cl.id, cl.code_customer, cl.phone,
       cl.arrival_date, cl.create_date, cl.create_on, cl.booking_date, cl.name, cl.amount_paid,
       cl.type_crm_id, cl.type_data_partner, cl.type, cl.active, cl.brand_id, cl.company_id,
       cl.campaign_id, cl.stage_id, cl.department_id, cl.source_id, cl.create_by,
       cl.create_by_department, cl.brand_etl, cl.state_id
from {{ source('dvda', 'crm_lead') }} cl
where cl.brand_etl = 0 and brand_id = 1
  and not exists (select 1 from {{ source('dvda', 'crm_lead') }} x where x.brand_etl = 1 and x.id = cl.id)
  and not exists (select 1 from {{ source('dvda', 'crm_sync_brand') }} x where x.brand_etl = 1 and x.id_old = cl.id)

union all

select cl.ticket_id, cl.overseas_vietnamese as vk, cl.contact_name, cl.id, cl.code_customer, cl.phone,
       cl.arrival_date, cl.create_date, cl.create_on, cl.booking_date, cl.name, cl.amount_paid,
       cl.type_crm_id, cl.type_data_partner, cl.type, cl.active, cl.brand_id, cl.company_id,
       cl.campaign_id, cl.stage_id, cl.department_id, cl.source_id, cl.create_by,
       cl.create_by_department, cl.brand_etl, cl.state_id
from {{ source('dvda', 'crm_lead') }} cl
where cl.brand_etl = 1 and cl.create_date < '20250801'

union all

select cl2.ticket_id, cl3.overseas_vietnamese as vk, cl3.contact_name, cl3.id, cl3.code_customer, cl3.phone,
       coalesce(cl2.arrival_date, cl3.arrival_date), cl2.create_date, cl2.create_on, cl2.booking_date,
       cl3.name, cl3.amount_paid, cl3.type_crm_id, cl3.type_data_partner, cl3.type, cl3.active,
       cl3.brand_id, cl3.company_id, cl2.campaign_id, cl3.stage_id, cl3.department_id,
       cl2.source_id, cl2.create_by, cl2.create_by_department, cl3.brand_etl, cl3.state_id
from {{ source('dvda', 'crm_sync_brand') }} csb
left join {{ source('dvda', 'crm_lead') }} cl2 on cl2.id = csb.id_old and cl2.brand_etl = 0
left join {{ source('dvda', 'crm_lead') }} cl3 on cl3.id = csb.crm_id and csb.brand_etl = cl3.brand_etl
where csb.brand_etl = 1

union all

select cl.ticket_id, cl.overseas_vietnamese as vk, cl.contact_name, cl.id, cl.code_customer, cl.phone,
       cl.arrival_date, cl.create_date, cl.create_on, cl.booking_date, cl.name, cl.amount_paid,
       cl.type_crm_id, cl.type_data_partner, cl.type, cl.active, cl.brand_id, cl.company_id,
       cl.campaign_id, cl.stage_id, cl.department_id, cl.source_id, cl.create_by,
       cl.create_by_department, cl.brand_etl, cl.state_id
from {{ source('dvda', 'crm_lead') }} cl
where cl.brand_etl = 1 and cl.create_date >= '20250801'
  and not exists (select 1 from {{ source('dvda', 'crm_sync_brand') }} x where x.brand_etl = 1 and x.crm_id = cl.id)
