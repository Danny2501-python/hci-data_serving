-- =============================================================================
-- int_frmacpr_union
-- PASS FINAL (trước mart): Union tất cả nguồn dữ liệu Paris thành 1 luồng.
-- Thứ tự UNION giữ nguyên như trong stored function gốc.
-- nguon_moi_v2/nhom_nguon_moi_v2: "nguồn mới"/"nhóm nguồn mới" (utm_source/
-- crm_category_source qua crm_lead.new_source_id) — chỉ populate được cho
-- các nhánh có liên kết CRM (ERP conv: Lead/BK/BKHL/DC/TC, và Doanh số);
-- NULL cho các nhánh cost/target không có customer linkage (FB/Google/
-- TikTok/Inbox/Targets) — cùng cách xử lý như func_report_marketing_ad_cost_kn.
-- =============================================================================

-- ERP conversions (Lead, BK, BKHL, DC, TC)
SELECT nguon, nhom_nguon, kenh, ngay, nhom_dv, chi_nhanh, metric, type_data,
    nguon_moi_v2, nhom_nguon_moi_v2, campaign, actor_code, nhom_dv_muc_tieu_code,
    vk, ten_dv, local_k_raw, quoc_gia, page_id_raw, page_code_raw, account_id_raw,
    nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM {{ ref('int_frmacpr_erp_conv') }}

UNION ALL

-- FB costs (Conversion + Brand)
SELECT nguon, nhom_nguon, channel AS kenh, ngay, nhom_dv, chi_nhanh, metric, type_data,
    nguon_moi_v2, nhom_nguon_moi_v2, campaign, actor_code, nhom_dv_muc_tieu_code,
    vk, ten_dv, local_k_raw, quoc_gia, page_id_raw, page_code_raw, account_id_raw,
    nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM {{ ref('stg_frmacpr_fb_insight_v3') }}

UNION ALL

-- Google Ads cost
SELECT nguon, nhom_nguon, channel AS kenh, ngay, nhom_dv, chi_nhanh, metric, type_data,
    nguon_moi_v2, nhom_nguon_moi_v2, campaign, actor_code, nhom_dv_muc_tieu_code,
    vk, ten_dv, local_k_raw, quoc_gia, page_id_raw, page_code_raw, account_id_raw,
    nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM {{ ref('stg_frmacpr_google') }}

UNION ALL

-- TikTok Ads cost
SELECT nguon, nhom_nguon, channel AS kenh, ngay, nhom_dv, chi_nhanh, metric, type_data,
    nguon_moi_v2, nhom_nguon_moi_v2, campaign, actor_code, nhom_dv_muc_tieu_code,
    vk, ten_dv, local_k_raw, quoc_gia, page_id_raw, page_code_raw, account_id_raw,
    nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM {{ ref('stg_frmacpr_tiktok') }}

UNION ALL

-- Inbox Facebook
SELECT nguon, nhom_nguon, channel AS kenh, ngay, nhom_dv, chi_nhanh, metric, type_data,
    nguon_moi_v2, nhom_nguon_moi_v2, campaign, actor_code, nhom_dv_muc_tieu_code,
    vk, ten_dv, local_k_raw, quoc_gia, page_id_raw, page_code_raw, account_id_raw,
    nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM {{ ref('stg_frmacpr_inbox') }}

UNION ALL

-- Doanh số
SELECT nguon, nhom_nguon, kenh, ngay, nhom_dv, chi_nhanh, metric, type_data,
    nguon_moi_v2, nhom_nguon_moi_v2, campaign, actor_code, nhom_dv_muc_tieu_code,
    vk, ten_dv, local_k_raw, quoc_gia, page_id_raw, page_code_raw, account_id_raw,
    nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM {{ ref('stg_frmacpr_doanh_so') }}

UNION ALL

-- Targets (Lead + Cost)
SELECT nguon, nhom_nguon, kenh, ngay, nhom_dv, chi_nhanh, metric, type_data,
    nguon_moi_v2, nhom_nguon_moi_v2, campaign, actor_code, nhom_dv_muc_tieu_code,
    vk, ten_dv, local_k_raw, quoc_gia, page_id_raw, page_code_raw, account_id_raw,
    nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM {{ ref('stg_frmacpr_targets') }}
