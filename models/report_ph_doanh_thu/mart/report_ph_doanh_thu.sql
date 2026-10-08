{{
  config(
    materialized = 'table',
    schema       = 'sandbox_ph',
    alias        = 'report_ph_doanh_thu',
    tags         = ['report_ph_doanh_thu', 'phi']
  )
}}
-- =============================================================================
-- report_ph_doanh_thu — doanh thu PHILIPPINES (ERP SUN, brand_etl = 9), 1 dòng / phiếu thu.
-- Ghi ra sandbox_ph.report_ph_doanh_thu. Xem README.md cùng thư mục.
--
-- Cách ly (không ảnh hưởng database):
--   * CHỈ đọc schema ph (+ public.ty_gia_acb khi bật tỷ giá ACB); KHÔNG join id ph với
--     bảng public (ERP SUN nhân bản từ ERP Kangnam -> id trùng).
--   * CHỈ ghi sandbox_ph (macro generate_schema_name).
-- Doanh số & tỷ giá lấy từ stg_frmacph_doanh_so_thu (dùng chung với báo cáo marketing _thu
-- và sale online -> 3 báo cáo luôn khớp nhau): posted, brand_etl = 9, phiếu của khách,
-- thu (+) / hoàn tiền (-), từ ngày go-live; công tắc tỷ giá var ph_nguon_ty_gia.
-- Thuộc tính khách: stg_frmacph_crm_base (cùng định nghĩa nguồn / kênh / nhóm DV với báo cáo
-- marketing) + ph.crm_lead. Trạng thái dữ liệu: stg_frmacph_trang_thai.
-- Báo cáo LUÔN lọc trang_thai_du_lieu = 'THAT'.
-- =============================================================================
WITH ds AS (
    SELECT * FROM {{ ref('stg_frmacph_doanh_so_thu') }}
),
crm AS (
    SELECT * FROM {{ ref('stg_frmacph_crm_base') }}
),
tt AS (
    SELECT * FROM {{ ref('stg_frmacph_trang_thai') }}
)
SELECT
    d.payment_id::integer                                   AS payment_id,
    ap.name::text                                           AS ma_phieu,
    d.ngay::date                                            AS ngay_thu,
    date_trunc('month', d.ngay)::date                       AS thang,
    CASE WHEN ap.payment_type = 'outbound' THEN 'HOAN_TIEN' ELSE 'THU' END::text AS loai_phieu,
    ap.company_id::integer                                  AS company_id,
    coalesce(d.chi_nhanh, 'KXĐ')::text                      AS chi_nhanh,
    d.loai_tien::text                                       AS loai_tien,
    d.so_tien_goc::numeric                                  AS so_tien_goc,
    d.ty_gia::numeric                                       AS ty_gia,
    d.ngay_ty_gia::date                                     AS ngay_ty_gia,
    d.nguon_ty_gia::text                                    AS nguon_ty_gia,
    d.doanh_so::numeric                                     AS doanh_thu_vnd,
    d.lead_id::integer                                      AS lead_id,
    l.type_crm_id::integer                                  AS loai_ban_ghi,
    (CASE WHEN l.type_crm_id = 2 THEN l.name END)::text     AS ma_booking,
    l.contact_name::text                                    AS ten_khach,
    l.code_customer::text                                   AS ma_kh,
    l.phone::text                                           AS sdt,
    coalesce(c.nguon, 'KXĐ')::text                          AS nguon,
    coalesce(c.nhom_nguon, 'KXĐ')::text                     AS nhom_nguon,
    coalesce(c.kenh, 'Khác')::text                          AS kenh,
    coalesce(c.quoc_gia, 'KXĐ')::text                       AS quoc_gia,
    coalesce(c.nhom_dv, 'KXĐ')::text                        AS nhom_dv,
    coalesce(c.ten_dv, 'DV')::text                          AS ten_dv,
    coalesce(t.trang_thai_du_lieu, 'NGHI_TEST')::text       AS trang_thai_du_lieu,
    coalesce(t.ly_do, 'Phiếu thu không gắn lead')::text     AS ly_do
FROM ds d
LEFT JOIN {{ source('ph', 'account_payment') }} ap ON ap.id = d.payment_id
LEFT JOIN {{ source('ph', 'crm_lead') }}        l  ON l.id  = d.lead_id
LEFT JOIN crm c                                     ON c.lead_id = d.lead_id
LEFT JOIN tt  t                                     ON t.lead_id = d.lead_id
