-- =============================================================================
-- int_frmacpr_union
-- PASS FINAL (trước mart): Union tất cả nguồn dữ liệu Paris thành 1 luồng.
-- Thứ tự UNION giữ nguyên như trong stored function gốc.
-- =============================================================================

-- ERP conversions (Lead, BK, BKHL, DC, TC)
SELECT nguon, nhom_nguon, kenh, ngay, nhom_dv, chi_nhanh, metric, type_data
FROM {{ ref('int_frmacpr_erp_conv') }}

UNION ALL

-- FB costs (Conversion + Brand)
SELECT nguon, nhom_nguon, channel AS kenh, ngay, nhom_dv, chi_nhanh, metric, type_data
FROM {{ ref('stg_frmacpr_fb_insight_v2') }}

UNION ALL

-- Google Ads cost
SELECT nguon, nhom_nguon, channel AS kenh, ngay, nhom_dv, chi_nhanh, metric, type_data
FROM {{ ref('stg_frmacpr_google') }}

UNION ALL

-- Inbox Facebook
SELECT nguon, nhom_nguon, channel AS kenh, ngay, nhom_dv, chi_nhanh, metric, type_data
FROM {{ ref('stg_frmacpr_inbox') }}

UNION ALL

-- Doanh số
SELECT nguon, nhom_nguon, kenh, ngay, nhom_dv, chi_nhanh, metric, type_data
FROM {{ ref('stg_frmacpr_doanh_so') }}

UNION ALL

-- Targets (Lead + Cost)
SELECT nguon, nhom_nguon, kenh, ngay, nhom_dv, chi_nhanh, metric, type_data
FROM {{ ref('stg_frmacpr_targets') }}
