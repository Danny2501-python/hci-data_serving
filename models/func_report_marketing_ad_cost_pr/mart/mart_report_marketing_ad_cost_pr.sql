{{
  config(
    materialized = 'table',
    alias        = 'report_marketing_ad_cost_pr_v2'
  )
}}
-- =============================================================================
-- mart_report_marketing_ad_cost_pr  (Final output)
-- Ghi đè toàn bộ bảng report_marketing_ad_cost_pr_v2 mỗi lần chạy.
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
    type_data,
    nguon_moi_v2,
    nhom_nguon_moi_v2
FROM {{ ref('int_frmacpr_union') }}
