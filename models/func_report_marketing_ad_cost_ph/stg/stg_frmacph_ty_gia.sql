{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_ty_gia — bảng tỷ giá DÙNG CHUNG cho báo cáo Philippines (số VND / 1 đơn vị).
-- Cột: loai_tien, ngay (NULL = áp mọi ngày), ty_gia, nguon ('VND' / 'ACB').
-- Nơi dùng lấy "dòng ngày gần nhất ≤ ngày cần quy đổi" (ORDER BY ngay DESC NULLS LAST LIMIT 1).
--
-- CHỈ DÙNG TỶ GIÁ ACB THEO NGÀY (từ 2026-10-09, user chốt; sếp duyệt ACB 2026-10-08):
--   * Bảng public.ty_gia_acb (pipeline data_ops dags/acb_fx, chốt 23:59 giờ VN, có từ
--     2026-09-10 = ngày go-live PH). Giá BÁN CHUYỂN KHOẢN (deal_type = 'ASK',
--     instrument_type = 'TRANSFER') cho mọi loại tiền – ACB chỉ niêm yết giá này cho PHP.
--   * VND luôn = 1.
--   * Ngày / loại tiền chưa có trong ty_gia_acb → nơi dùng ra nguon_ty_gia 'THIEU_TY_GIA',
--     doanh số NULL; test tests/ph/assert_ph_doanh_thu_co_ty_gia báo lỗi (không âm thầm sai).
-- Lịch sử: 07–08/10/2026 từng dùng tạm tỷ giá CỐ ĐỊNH theo chỉ đạo sếp (PHP 405, USD 25.806,79
-- TB mua CK Techcombank, AUD 18.315,78) qua công tắc var ph_nguon_ty_gia – đã BỎ, xem git history.
-- =============================================================================
SELECT 'VND'::text AS loai_tien, NULL::date AS ngay, 1::numeric AS ty_gia, 'VND'::text AS nguon
UNION ALL
SELECT a.loai_tien, a.ngay, a.ty_gia, 'ACB'
FROM {{ source('acb_fx', 'ty_gia_acb') }} a
WHERE a.deal_type = 'ASK'
  AND a.instrument_type = 'TRANSFER'
