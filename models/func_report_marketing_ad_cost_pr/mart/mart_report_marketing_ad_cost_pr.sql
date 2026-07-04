{{
  config(
    materialized = 'table',
    alias        = 'report_marketing_ad_cost_pr'
  )
}}
-- =============================================================================
-- mart_report_marketing_ad_cost_pr  (Final output)
-- Ghi đè toàn bộ bảng report_marketing_ad_cost_pr mỗi lần chạy.
-- Đây là model table duy nhất trong pipeline Paris.
-- =============================================================================

SELECT
    nguon,
    nhom_nguon,
    kenh,
    ngay::timestamp AS "date",
    nhom_dv,
    chi_nhanh,
    metric  AS "dt",
    type_data
FROM {{ ref('int_frmacpr_union') }}
