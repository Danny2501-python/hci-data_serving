{{
  config(
    materialized = 'table',
    alias        = 'stg_hqcd_mv_cline'
  )
}}
-- =============================================================================
-- stg_hqcd_mv_cline  (thay thế MATERIALIZED VIEW public.mv_cline)
-- Xử lý cross-brand ETL deduplication cho crm_line
-- part_line:
--   1 = brand_etl=1, create_date >= T8/2025, chưa sync
--   2 = sync record (line_id)
--   3 = brand_etl=1, create_date < T8/2025
--   4 = brand_etl=0, chưa sync, chưa có trong sync_brand
--   5 = brand_etl=0, chưa có bản brand_etl=1
--   6 = sync record (id cũ)
-- =============================================================================

with cline as (

    -- Part 5: brand cũ (0), chưa có bản brand mới (1)
    select cl.id, cl.crm_id, cl.product_id, cl.stage, cl.create_date,
           cl.brand_etl, cl.create_uid, 5 as part_line,
           cl.total_received, cl.percent_total_discount
    from {{ source('hqcd', 'crm_line') }} cl
    where cl.brand_etl = 0
      and cl.brand_id  = 1
      and not exists (
          select 1 from {{ source('hqcd', 'crm_line') }} cl2
          where cl2.brand_etl = 1 and cl2.id = cl.id
      )

    union all

    -- Part 4: brand cũ (0), chưa sync sang brand mới, chưa có sync_brand
    select cl.id, cl.crm_id, cl.product_id, cl.stage, cl.create_date,
           cl.brand_etl, cl.create_uid, 4 as part_line,
           cl.total_received, cl.percent_total_discount
    from {{ source('hqcd', 'crm_line') }} cl
    where cl.brand_etl = 0
      and cl.brand_id  = 1
      and not exists (
          select 1 from {{ source('hqcd', 'crm_line') }} cl2
          where cl2.brand_etl = 1 and cl2.id = cl.id
      )
      and not exists (
          select 1 from {{ source('hqcd', 'crm_sync_brand') }} csb
          where csb.brand_etl = 1 and csb.id_old = cl.id
      )

    union all

    -- Part 3: brand mới (1), dữ liệu trước T8/2025
    select cl.id, cl.crm_id, cl.product_id, cl.stage, cl.create_date,
           cl.brand_etl, cl.create_uid, 3 as part_line,
           cl.total_received, cl.percent_total_discount
    from {{ source('hqcd', 'crm_line') }} cl
    where cl.brand_etl = 1
      and cl.create_date < '2025-08-01'

    union all

    -- Part 2: sync line record (lấy id cũ)
    select cl2.id, cl3.crm_id, cl2.product_id, cl3.stage, cl2.create_date,
           csl.brand_etl, cl2.create_uid, 2 as part_line,
           cl2.total_received, cl2.percent_total_discount
    from {{ source('hqcd', 'crm_sync_crm_line') }} csl
    left join {{ source('hqcd', 'crm_line') }} cl2
           on cl2.id = csl.id_old and cl2.brand_etl = 0
    left join {{ source('hqcd', 'crm_line') }} cl3
           on cl3.id = csl.crm_line_id and csl.brand_etl = cl3.brand_etl
    where csl.brand_etl = 1

    union all

    -- Part 6: sync line record (lấy id mới)
    select cl3.id, cl3.crm_id, cl2.product_id, cl3.stage, cl2.create_date,
           csl.brand_etl, cl3.create_uid, 6 as part_line,
           cl3.total_received, cl3.percent_total_discount
    from {{ source('hqcd', 'crm_sync_crm_line') }} csl
    left join {{ source('hqcd', 'crm_line') }} cl2
           on cl2.id = csl.id_old and cl2.brand_etl = 0
    left join {{ source('hqcd', 'crm_line') }} cl3
           on cl3.id = csl.crm_line_id and csl.brand_etl = cl3.brand_etl
    where csl.brand_etl = 1

    union all

    -- Part 1: brand mới (1), từ T8/2025, chưa được sync
    select cl.id, cl.crm_id, cl.product_id, cl.stage, cl.create_date,
           cl.brand_etl, cl.create_uid, 1 as part_line,
           cl.total_received, cl.percent_total_discount
    from {{ source('hqcd', 'crm_line') }} cl
    where cl.brand_etl = 1
      and cl.create_date >= '2025-08-01'
      and not exists (
          select 1 from {{ source('hqcd', 'crm_sync_crm_line') }} csb
          where csb.brand_etl = 1 and csb.crm_line_id = cl.id
      )

)

select * from cline
