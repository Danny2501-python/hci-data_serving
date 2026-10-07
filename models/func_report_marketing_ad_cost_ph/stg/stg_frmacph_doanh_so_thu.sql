{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_doanh_so_thu — BẢN TÍNH THỬ của stg_frmacph_doanh_so.
-- Lý do: ở ERP PH, amount_vnd KHÔNG phải VND (phiếu PHP: amount_vnd = amount, tức vẫn
-- là PHP; vài phiếu có tỷ giá rác, vd 10.000 PHP → 1). Bản thử quy đổi lại từ
-- amount + currency_id theo tỷ giá của ngày thu (lấy ngày gần nhất ≤ ngày thu).
--
-- Nguồn tỷ giá (CTE ty_gia: loai_tien, ngay, ty_gia = số VND / 1 đơn vị tiền):
--   * HIỆN TẠI (từ 2026-10-07, theo chỉ đạo của sếp – DÙNG TẠM cho tới khi có giải pháp
--     lâu dài): TỶ GIÁ CỐ ĐỊNH, 1 con số / loại tiền (ngay = NULL → áp cho mọi ngày):
--       USD = 25.806,79 : trung bình tỷ giá MUA CHUYỂN KHOẢN Techcombank
--                         (public.ty_gia_techcombank, 29 ngày 03/09 → 06/10/2026)
--       PHP =    405    : con số cố định do sếp chốt (2026-10-07). Tham khảo: tỷ giá chéo
--                         USD Techcombank ÷ 62,6482 (PHP/USD thị trường) = 411,93 –
--                         Techcombank không niêm yết PHP.
--       AUD = 18.315,78 : tỷ giá chéo = USD Techcombank × 0,7097 (USD/AUD trung bình cùng kỳ)
--     Không còn phụ thuộc seed ucbt_ty_gia_ph / script update_ty_gia_ph.py chạy trên máy cá
--     nhân (giữ lại để tham khảo). Với tỷ giá cố định, ngay_ty_gia = ngày thu.
--   * TRƯỚC 2026-10-07: seed ucbt_ty_gia_ph – tỷ giá thị trường theo ngày (xem git history).
--   * KHI ETL XONG bảng tỷ giá ERP PH: thay CTE ty_gia bằng select từ bảng đó
--     (1 dòng / loại tiền / ngày) – phần còn lại giữ nguyên.
-- Loại tiền không có tỷ giá → doanh_so NULL (không âm thầm cộng sai).
-- =============================================================================
WITH ty_gia (loai_tien, ngay, ty_gia) AS (
    VALUES
        ('VND'::text, NULL::date, 1::numeric),
        ('USD',       NULL,       25806.79),
        ('PHP',       NULL,       405),
        ('AUD',       NULL,       18315.78)
)
SELECT
    p.id                                                    AS payment_id,
    p.crm_id                                                AS lead_id,
    p.payment_date                                          AS ngay,
    round(
        CASE WHEN p.payment_type = 'outbound' THEN -1 ELSE 1 END
      * p.amount * tg.ty_gia
    )                                                       AS doanh_so,
    co.name                                                 AS chi_nhanh,
    cur.name                                                AS loai_tien,
    CASE WHEN p.payment_type = 'outbound' THEN -1 ELSE 1 END
      * p.amount                                            AS so_tien_goc,
    tg.ty_gia,
    CASE WHEN cur.name = 'VND' THEN p.payment_date
         ELSE coalesce(tg.ngay, p.payment_date) END         AS ngay_ty_gia
FROM {{ source('ph', 'account_payment') }} p
LEFT JOIN {{ source('ph', 'res_currency') }} cur ON cur.id = p.currency_id
LEFT JOIN {{ source('ph', 'm_res_company') }} co ON co.id = p.company_id
LEFT JOIN LATERAL (     -- tỷ giá ngày gần nhất ≤ ngày thu (ngay NULL = áp mọi ngày)
    SELECT t.ngay, t.ty_gia FROM ty_gia t
    WHERE t.loai_tien = cur.name AND (t.ngay IS NULL OR t.ngay <= p.payment_date)
    ORDER BY t.ngay DESC NULLS LAST
    LIMIT 1
) tg ON TRUE
WHERE p.state = 'posted'
