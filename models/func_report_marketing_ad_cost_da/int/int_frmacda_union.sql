{{
  config(
    materialized = 'ephemeral'
  )
}}

-- =============================================================================
-- int_frmacda_union — bản ĐÔNG Á của int_frmack_union (Kangnam).
-- UNION 6 nhánh có dữ liệu ERP: DC, DS, Lead, TC, BKHL, HL. Điều kiện từng
-- nhánh giữ như Kangnam, TRỪ 1 điểm:
--
-- [KHÁC KANGNAM] Kangnam lọc `nhom_dv <> 'SAN PHAM'` -> dòng có nhom_dv NULL
-- (lead/booking CHƯA có dòng dịch vụ crm_line) bị loại luôn, vì NULL <> 'x'
-- không bao giờ TRUE. Với Đông Á điều này loại gần hết lead: kiểm tra trên
-- staging_sci 21/10/2026 chỉ còn 6 SĐT Lead / 335 lead thật. Bản Đông Á dùng
-- COALESCE(nhom_dv, '') <> 'SAN PHAM' để giữ lại các dòng này, nhom_dv = 'KXĐ'.
--
-- CHƯA có (thêm khi kéo được dữ liệu Đông Á):
--   - Inbox, DealCS : cần CareSoft Đông Á
--   - GG            : cần chi phí Google Ads Đông Á
--   - campaign / page / actor / account_fb : cần ad_id từ ticket CareSoft
--     -> hiện để 'KXĐ' / NULL, giữ đủ cột để dùng chung mart / Tableau với Kangnam.
-- =============================================================================

WITH cb AS (
    SELECT * FROM {{ ref('stg_frmacda_crm_base') }}
)

-- DC
SELECT
    vk, ten_dv, "Nguon" AS nguon, "Nhom_nguon" AS nhom_nguon, kenh,
    ngay_den_cua AS ngay, COALESCE(nhom_dv, 'KXĐ') AS nhom_dv, chi_nhanh_new AS chi_nhanh,
    local_k, quoc_gia, sdt::text AS metric,
    'DC'::text AS type_data, ticket_id,
    'KXĐ'::text AS campaign,
    'KXĐ'::text AS page_name,
    NULL::text  AS page_id_from_camp,
    NULL::text  AS actor_code,
    NULL::text  AS account_fb,
    NULL::text  AS nhom_dv_muc_tieu_code,
    nhom_dv_KH_quan_tam::text     AS nhom_dv_KH_quan_tam,
    nhom_dv_KH_quan_tam_goc::text AS nhom_dv_KH_quan_tam_goc,
    nhom_dv_chinh_booking::text   AS nhom_dv_chinh_booking,
    nguon_moi_v2::text            AS nguon_moi_v2,
    nhom_nguon_moi_v2::text       AS nhom_nguon_moi_v2
FROM cb
WHERE ngay_den_cua >= '{{ var("start_date", "2025-08-01") }}'::date
  AND COALESCE(nhom_dv, '') <> 'SAN PHAM' AND loai_ban_ghi = 2
  AND (reason_cancel_booking NOT IN ('tao_booking_bh') OR reason_cancel_booking IS NULL)

UNION ALL
-- DS
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id,
    'KXĐ'::text, 'KXĐ'::text, NULL::text, NULL::text, NULL::text, NULL::text,
    nhom_dv_KH_quan_tam::text,
    nhom_dv_KH_quan_tam_goc::text,
    nhom_dv_chinh_booking::text,
    nguon_moi_v2::text,
    nhom_nguon_moi_v2::text
FROM {{ ref('stg_frmacda_doanh_so') }}
WHERE ngay >= '{{ var("start_date", "2025-08-01") }}'::date

UNION ALL
-- Lead
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_tao, COALESCE(nhom_dv, 'KXĐ'), chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'Lead', ticket_id,
    'KXĐ'::text, 'KXĐ'::text, NULL::text, NULL::text, NULL::text, NULL::text,
    nhom_dv_KH_quan_tam::text,
    nhom_dv_KH_quan_tam_goc::text,
    nhom_dv_chinh_booking::text,
    nguon_moi_v2::text,
    nhom_nguon_moi_v2::text
FROM cb
WHERE ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
  AND COALESCE(nhom_dv, '') <> 'SAN PHAM' AND loai_ban_ghi = 1

UNION ALL
-- TC
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_den_cua, COALESCE(nhom_dv, 'KXĐ'), chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'TC', ticket_id,
    'KXĐ'::text, 'KXĐ'::text, NULL::text, NULL::text, NULL::text, NULL::text,
    nhom_dv_KH_quan_tam::text,
    nhom_dv_KH_quan_tam_goc::text,
    nhom_dv_chinh_booking::text,
    nguon_moi_v2::text,
    nhom_nguon_moi_v2::text
FROM cb
WHERE ngay_den_cua >= '{{ var("start_date", "2025-08-01") }}'::date
  AND COALESCE(nhom_dv, '') <> 'SAN PHAM' AND tong_tien > 0 AND loai_ban_ghi = 2
  AND (reason_cancel_booking <> 'tao_booking_bh' OR reason_cancel_booking IS NULL)

UNION ALL
-- BKHL
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_tao, COALESCE(nhom_dv, 'KXĐ'), chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'BKHL', ticket_id,
    'KXĐ'::text, 'KXĐ'::text, NULL::text, NULL::text, NULL::text, NULL::text,
    nhom_dv_KH_quan_tam::text,
    nhom_dv_KH_quan_tam_goc::text,
    nhom_dv_chinh_booking::text,
    nguon_moi_v2::text,
    nhom_nguon_moi_v2::text
FROM cb
WHERE ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
  AND COALESCE(nhom_dv, '') <> 'SAN PHAM' AND loai_ban_ghi = 2
  AND (reason_cancel_booking <> 'tao_booking_bh' OR reason_cancel_booking IS NULL)

UNION ALL
-- HL
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_hl, COALESCE(nhom_dv, 'KXĐ'), chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'HL', ticket_id,
    'KXĐ'::text, 'KXĐ'::text, NULL::text, NULL::text, NULL::text, NULL::text,
    nhom_dv_KH_quan_tam::text,
    nhom_dv_KH_quan_tam_goc::text,
    nhom_dv_chinh_booking::text,
    nguon_moi_v2::text,
    nhom_nguon_moi_v2::text
FROM cb
WHERE ngay_hl >= '{{ var("start_date", "2025-08-01") }}'::date
  AND COALESCE(nhom_dv, '') <> 'SAN PHAM' AND loai_ban_ghi = 2
  AND (reason_cancel_booking <> 'tao_booking_bh' OR reason_cancel_booking IS NULL)
