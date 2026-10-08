{{
  config(
    materialized = 'table',
    schema       = 'sandbox_ph',
    alias        = 'report_ph_doanh_thu_chi_phi',
    tags         = ['report_ph_doanh_thu', 'phi']
  )
}}
-- =============================================================================
-- report_ph_doanh_thu_chi_phi — DOANH THU + CHI PHÍ Philippines theo ngày, dạng DÒNG
-- (mỗi dòng 1 khoản tiền). Ghi ra sandbox_ph.report_ph_doanh_thu_chi_phi. Xem README.md.
--
--   nhom       khoan_muc            nguồn
--   DOANH_THU  THU_TIEN / HOAN_TIEN report_ph_doanh_thu (phiếu thu ERP PH, brand_etl = 9)
--   CHI_PHI    QUANG_CAO_FACEBOOK   stg_frmacph_fb_cost (campaign 'sun_', cs_facebook_insight brand 1,
--                                   số tiền VND – cùng nguồn với báo cáo marketing PH)
--   CHI_PHI    VAT_TU_TIEU_HAO      stg_frmacph_vat_tu (giá trị xuất kho ERP PH)
--
-- so_tien_vnd        : số tiền theo bản chất (doanh thu +, hoàn tiền -, chi phí +, trả lại kho -)
-- tac_dong_loi_nhuan : DOANH_THU giữ nguyên, CHI_PHI đổi dấu -> SUM(tac_dong_loi_nhuan) = lãi gộp
-- Doanh thu: lọc trang_thai_du_lieu = 'THAT' khi làm báo cáo. Chi phí luôn 'THAT'.
-- ERP PH (07/10/2026) CHƯA ghi nhận chi phí nào khác (không hoá đơn mua hàng, phiếu chi NCC,
-- chi phí nhân viên) -> khi ERP có, bổ sung khoản mục mới vào UNION bên dưới.
-- =============================================================================
WITH dt AS (
    SELECT * FROM {{ ref('report_ph_doanh_thu') }}
),
fb AS (
    SELECT
        f.ngay::date                   AS ngay,
        f.campaign_id::text            AS campaign_id,
        max(f.camp_name)               AS camp_name,
        sum(f.chi_phi)::numeric        AS chi_phi
    FROM {{ ref('stg_frmacph_fb_cost') }} f
    WHERE f.ngay::date >= '{{ var("ph_go_live_date", "2026-09-10") }}'::date
    GROUP BY 1, 2
),
vt AS (
    SELECT * FROM {{ ref('stg_frmacph_vat_tu') }}
)

-- ── Doanh thu: 1 dòng / phiếu thu ───────────────────────────────────────────
SELECT
    dt.ngay_thu                                             AS ngay,
    date_trunc('month', dt.ngay_thu)::date                  AS thang,
    'DOANH_THU'::text                                       AS nhom,
    (CASE WHEN dt.loai_phieu = 'HOAN_TIEN' THEN 'HOAN_TIEN' ELSE 'THU_TIEN' END)::text AS khoan_muc,
    dt.company_id::integer                                  AS company_id,
    dt.chi_nhanh::text                                      AS chi_nhanh,
    dt.doanh_thu_vnd::numeric                               AS so_tien_vnd,
    dt.doanh_thu_vnd::numeric                               AS tac_dong_loi_nhuan,
    dt.loai_tien::text                                      AS loai_tien_goc,
    dt.so_tien_goc::numeric                                 AS so_tien_goc,
    dt.ty_gia::numeric                                      AS ty_gia,
    dt.nguon_ty_gia::text                                   AS nguon_ty_gia,
    'ERP PH - account_payment'::text                        AS nguon_du_lieu,
    dt.ma_phieu::text                                       AS ma_chung_tu,
    concat_ws(' | ', dt.ten_khach, dt.ma_booking, dt.nhom_dv, dt.nguon)::text AS chi_tiet,
    dt.lead_id::integer                                     AS lead_id,
    dt.trang_thai_du_lieu::text                             AS trang_thai_du_lieu,
    dt.ly_do::text                                          AS ly_do
FROM dt

UNION ALL
-- ── Chi phí quảng cáo Facebook: 1 dòng / ngày / campaign ───────────────────
SELECT
    fb.ngay,
    date_trunc('month', fb.ngay)::date,
    'CHI_PHI',
    'QUANG_CAO_FACEBOOK',
    NULL::integer,
    'SUNWOO MEDICAL CENTER',               -- giống báo cáo marketing PH (chi phí theo thương hiệu)
    fb.chi_phi,
    -fb.chi_phi,
    'VND',
    fb.chi_phi,
    1::numeric,
    'VND',
    'Facebook - campaign sun_ (cs_facebook_insight brand 1)',
    fb.campaign_id,
    fb.camp_name,
    NULL::integer,
    'THAT',
    'Chi phí quảng cáo FB thực tế'
FROM fb

UNION ALL
-- ── Chi phí vật tư tiêu hao: 1 dòng / lớp định giá xuất kho ───────────────
SELECT
    vt.ngay,
    date_trunc('month', vt.ngay)::date,
    'CHI_PHI',
    'VAT_TU_TIEU_HAO',
    vt.company_id::integer,
    coalesce(co.name, 'KXĐ'),
    vt.chi_phi_vnd::numeric,
    -vt.chi_phi_vnd::numeric,
    vt.loai_tien_goc,
    vt.gia_tri_goc::numeric,
    vt.ty_gia::numeric,
    vt.nguon_ty_gia,
    'ERP PH - stock_valuation_layer',
    vt.ma_chung_tu,
    concat_ws(' | ', vt.vat_tu, 'SL ' || vt.so_luong::text),
    NULL::integer,
    'THAT',
    (CASE WHEN vt.tu_kho = 'internal' THEN 'Xuất kho ' ELSE 'Trả lại kho ' END)
      || vt.tu_kho || ' -> ' || vt.den_kho || ' (giá vốn ' || vt.loai_tien_goc || ')'
FROM vt
LEFT JOIN {{ source('ph', 'm_res_company') }} co ON co.id = vt.company_id
