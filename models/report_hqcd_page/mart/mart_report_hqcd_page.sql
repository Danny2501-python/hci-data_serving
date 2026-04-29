{{
  config(
    materialized = 'table',
    alias        = 'report_hqcd_page'
  )
}}
-- =============================================================================
-- mart_report_hqcd_page
-- Báo cáo HQCD theo Page Facebook — union 5 luồng:
--   Lead | Deal | Inbox | Cost | DS
-- Output: khớp 100% với report_hqcd_page_old.sql (kể cả ?column?)
-- =============================================================================

select date, metric, bang, page, ticket_id, sub_mt, 0,
       email, bp, page_id, dv_mb, dv_ht, local, vk, rnk
from {{ ref('int_hqcd_page_lead') }}

union all
select date, metric, bang, page, ticket_id, sub_mt, 0,
       email, bp, page_id, dv_mb, dv_ht, local, vk, 0 as rnk
from {{ ref('int_hqcd_page_deal') }}

union all
select date, metric, bang, page, ticket_id, sub_mt, 0,
       email, bp, page_id, dv_mb, dv_ht, local, vk, 0 as rnk
from {{ ref('int_hqcd_page_inbox') }}

union all
select date, metric, bang, page, ticket_id, sub_mt, 0,
       email, bp, page_id, dv_mb, dv_ht, local, vk, 0 as rnk
from {{ ref('int_hqcd_page_cost') }}

union all
select date, metric, bang, page, ticket_id, sub_mt, 0,
       email, bp, page_id, dv_mb, dv_ht, local, vk, 0 as rnk
from {{ ref('int_hqcd_page_ds') }}
