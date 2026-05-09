{{
  config(
    materialized = 'table',
    alias        = 'stg_rhp_mv_ecl'
  )
}}
-- =============================================================================
-- stg_rhp_mv_ecl  (thay thế MATERIALIZED VIEW public.mv_ecl)
-- Xử lý cross-brand ETL deduplication cho crm_lead
-- part:
--   1 = brand_etl=1, create_date >= T8/2025, chưa sync
--   2 = sync record (lead_id cũ)
--   3 = brand_etl=1, create_date < T8/2025
--   4 = brand_etl=0, chưa sync, chưa có trong sync_brand
--   5 = brand_etl=0, chưa có bản brand_etl=1
--   6 = sync record (id mới)
-- =============================================================================

with ecl as (

    -- Part 5: brand cũ (0), chưa có bản brand mới (1)
    select cl.lead_id, cl.ticket_id, cl.overseas_vietnamese, cl.contact_name,
           cl.id, cl.code_customer, cl.phone, cl.arrival_date, cl.create_date,
           cl.create_on, cl.booking_date, cl.name, cl.amount_paid, cl.type_crm_id,
           cl.type_data_partner, cl.type, cl.active, cl.brand_id, cl.company_id,
           cl.campaign_id, cl.stage_id, cl.department_id, cl.source_id,
           cl.create_by, cl.create_by_department, cl.brand_etl, cl.state_id,
           5 as part
    from {{ source('rhp', 'crm_lead') }} cl
    where cl.brand_etl = 0
      and cl.brand_id  = 1
      and not exists (
          select 1 from {{ source('rhp', 'crm_lead') }} cl2
          where cl2.brand_etl = 1 and cl2.id = cl.id
      )

    union all

    -- Part 4: brand cũ (0), chưa có bản brand mới, chưa có trong sync_brand
    select cl.lead_id, cl.ticket_id, cl.overseas_vietnamese, cl.contact_name,
           cl.id, cl.code_customer, cl.phone, cl.arrival_date, cl.create_date,
           cl.create_on, cl.booking_date, cl.name, cl.amount_paid, cl.type_crm_id,
           cl.type_data_partner, cl.type, cl.active, cl.brand_id, cl.company_id,
           cl.campaign_id, cl.stage_id, cl.department_id, cl.source_id,
           cl.create_by, cl.create_by_department, cl.brand_etl, cl.state_id,
           4 as part
    from {{ source('rhp', 'crm_lead') }} cl
    where cl.brand_etl = 0
      and cl.brand_id  = 1
      and not exists (
          select 1 from {{ source('rhp', 'crm_lead') }} cl2
          where cl2.brand_etl = 1 and cl2.id = cl.id
      )
      and not exists (
          select 1 from {{ source('rhp', 'crm_sync_brand') }} csb
          where csb.brand_etl = 1 and csb.id_old = cl.id
      )

    union all

    -- Part 3: brand mới (1), dữ liệu trước T8/2025
    select cl.lead_id, cl.ticket_id, cl.overseas_vietnamese, cl.contact_name,
           cl.id, cl.code_customer, cl.phone, cl.arrival_date, cl.create_date,
           cl.create_on, cl.booking_date, cl.name, cl.amount_paid, cl.type_crm_id,
           cl.type_data_partner, cl.type, cl.active, cl.brand_id, cl.company_id,
           cl.campaign_id, cl.stage_id, cl.department_id, cl.source_id,
           cl.create_by, cl.create_by_department, cl.brand_etl, cl.state_id,
           3 as part
    from {{ source('rhp', 'crm_lead') }} cl
    where cl.brand_etl = 1
      and cl.create_date < '2025-08-01'

    union all

    -- Part 2: sync record — lấy thông tin từ id cũ (brand 0) + id mới (brand 1)
    select cl2.lead_id, cl2.ticket_id, cl3.overseas_vietnamese, cl3.contact_name,
           cl2.id, cl3.code_customer, cl3.phone,
           case when cl2.arrival_date is not null then cl2.arrival_date
                when cl3.arrival_date is not null then cl3.arrival_date
                else null end as arrival_date,
           cl2.create_date, cl2.create_on, cl2.booking_date, cl3.name,
           cl3.amount_paid, cl3.type_crm_id, cl3.type_data_partner, cl3.type,
           cl3.active, cl3.brand_id, cl3.company_id, cl2.campaign_id,
           cl3.stage_id, cl3.department_id, cl2.source_id,
           cl2.create_by, cl2.create_by_department, cl3.brand_etl, cl3.state_id,
           2 as part
    from {{ source('rhp', 'crm_sync_brand') }} csb
    left join {{ source('rhp', 'crm_lead') }} cl2
           on cl2.id = csb.id_old and cl2.brand_etl = 0
    left join {{ source('rhp', 'crm_lead') }} cl3
           on cl3.id = csb.crm_id and csb.brand_etl = cl3.brand_etl
    where csb.brand_etl = 1

    union all

    -- Part 6: sync record — lấy id của brand mới
    select cl2.lead_id, cl2.ticket_id, cl3.overseas_vietnamese, cl3.contact_name,
           cl3.id, cl3.code_customer, cl3.phone,
           case when cl2.arrival_date is not null then cl2.arrival_date
                when cl3.arrival_date is not null then cl3.arrival_date
                else null end as arrival_date,
           cl2.create_date, cl2.create_on, cl2.booking_date, cl3.name,
           cl3.amount_paid, cl3.type_crm_id, cl3.type_data_partner, cl3.type,
           cl3.active, cl3.brand_id, cl3.company_id, cl2.campaign_id,
           cl3.stage_id, cl3.department_id, cl2.source_id,
           cl2.create_by, cl2.create_by_department, cl3.brand_etl, cl3.state_id,
           6 as part
    from {{ source('rhp', 'crm_sync_brand') }} csb
    left join {{ source('rhp', 'crm_lead') }} cl2
           on cl2.id = csb.id_old and cl2.brand_etl = 0
    left join {{ source('rhp', 'crm_lead') }} cl3
           on cl3.id = csb.crm_id and csb.brand_etl = cl3.brand_etl
    where csb.brand_etl = 1

    union all

    -- Part 1: brand mới (1), từ T8/2025, chưa được sync
    select cl.lead_id, cl.ticket_id, cl.overseas_vietnamese, cl.contact_name,
           cl.id, cl.code_customer, cl.phone, cl.arrival_date, cl.create_date,
           cl.create_on, cl.booking_date, cl.name, cl.amount_paid, cl.type_crm_id,
           cl.type_data_partner, cl.type, cl.active, cl.brand_id, cl.company_id,
           cl.campaign_id, cl.stage_id, cl.department_id, cl.source_id,
           cl.create_by, cl.create_by_department, cl.brand_etl, cl.state_id,
           1 as part
    from {{ source('rhp', 'crm_lead') }} cl
    where cl.brand_etl = 1
      and cl.create_date >= '2025-08-01'
      and not exists (
          select 1 from {{ source('rhp', 'crm_sync_brand') }} csb
          where csb.brand_etl = 1 and csb.crm_id = cl.id
      )

)

select * from ecl

