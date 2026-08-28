{{
  config(materialized = 'table')
}}
-- =============================================================================
-- mart_rpdc_daily_chinhanh
-- Gộp 7 stag: lead_book / den_cua / doanh_so / hen_lich / cost_fb / cost_gg / cost_tiktok.
-- =============================================================================
SELECT * FROM {{ ref('stg_rpdc_lead_book') }}
UNION ALL
SELECT * FROM {{ ref('stg_rpdc_den_cua') }}
UNION ALL
SELECT * FROM {{ ref('stg_rpdc_doanh_so') }}
UNION ALL
SELECT * FROM {{ ref('stg_rpdc_hen_lich') }}
UNION ALL
SELECT * FROM {{ ref('stg_rpdc_cost_fb') }}
UNION ALL
SELECT * FROM {{ ref('stg_rpdc_cost_gg') }}
UNION ALL
SELECT * FROM {{ ref('stg_rpdc_cost_tiktok') }}