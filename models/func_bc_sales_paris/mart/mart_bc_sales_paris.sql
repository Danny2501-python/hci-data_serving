{{
  config(
    materialized = 'table',
    alias        = 'bc_sales_paris_v2'
  )
}}
-- =============================================================================
-- mart_bc_sales_paris  (Pass 12 — Final output)
-- UNION ALL theo thứ tự gốc:
--   Stream 1 (Inbox)    : int_bsp_inbox
--   Stream 2 (CRM)      : int_bsp_crm_union (Lead/BK/HL/DC/TC/DS)
--   Stream 3 (Chi phí)  : int_bsp_fb_cost
-- =============================================================================

SELECT * FROM {{ ref('int_bsp_inbox') }}

UNION ALL

SELECT * FROM {{ ref('int_bsp_crm_union') }}

UNION ALL

SELECT * FROM {{ ref('int_bsp_fb_cost') }}
