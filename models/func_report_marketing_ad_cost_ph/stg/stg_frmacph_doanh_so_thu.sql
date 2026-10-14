{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_doanh_so_thu — doanh số ERP PH quy đổi VND (dùng chung cho
-- mart_report_marketing_ad_cost_ph_thu, report_ph_sale_online, report_ph_doanh_thu).
-- Lý do: ở ERP PH, amount_vnd KHÔNG phải VND (phiếu PHP: amount_vnd = amount, tức vẫn
-- là PHP; vài phiếu có tỷ giá rác, vd 10.000 PHP → 1). Quy đổi lại từ
-- amount + currency_id theo tỷ giá của ngày thu (lấy ngày gần nhất ≤ ngày thu).
--
-- Tỷ giá: stg_frmacph_ty_gia (dùng chung) – chỉ ACB theo ngày (bán chuyển khoản), từ 2026-10-09.
-- [2026-10-08] Thêm chốt chặn: brand_etl = 9, phiếu của khách (partner_type = 'customer'),
-- chỉ phiếu thu / hoàn (inbound / outbound), ngày thu ≥ var('ph_go_live_date').
-- Loại tiền không có tỷ giá → doanh_so NULL, nguon_ty_gia 'THIEU_TY_GIA'
-- (không âm thầm cộng sai; test tests/ph/assert_ph_doanh_thu_co_ty_gia bắt lỗi).
-- [2026-10-13] Thêm doanh_so_php + ty_gia_php (tỷ giá PHP ACB ngày gần nhất ≤ ngày thu).
-- Phiếu PHP: doanh_so_php = số tiền gốc (khớp ERP); loại tiền khác: doanh_so ÷ ty_gia_php.
-- Các model dùng bảng này đều chọn cột đích danh → chỉ bảng nào chọn thêm mới có 2 cột này.
-- =============================================================================
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
         ELSE coalesce(tg.ngay, p.payment_date) END         AS ngay_ty_gia,
    coalesce(tg.nguon, 'THIEU_TY_GIA')                      AS nguon_ty_gia,
    -- [2026-10-13] Doanh số quy đổi PHP (để Tableau chọn xem VND / PHP):
    --   phiếu PHP → đúng số tiền gốc trên ERP; loại tiền khác → doanh số VND ÷ tỷ giá PHP ACB.
    tgp.ty_gia                                              AS ty_gia_php,
    CASE WHEN cur.name = 'PHP'
         THEN CASE WHEN p.payment_type = 'outbound' THEN -1 ELSE 1 END * p.amount
         ELSE round(
                CASE WHEN p.payment_type = 'outbound' THEN -1 ELSE 1 END
              * p.amount * tg.ty_gia / nullif(tgp.ty_gia, 0), 2)
    END                                                     AS doanh_so_php
FROM {{ source('ph', 'account_payment') }} p
LEFT JOIN {{ source('ph', 'res_currency') }} cur ON cur.id = p.currency_id
LEFT JOIN {{ source('ph', 'm_res_company') }} co ON co.id = p.company_id
LEFT JOIN LATERAL (     -- tỷ giá ngày gần nhất ≤ ngày thu (ngay NULL = áp mọi ngày)
    SELECT t.ngay, t.ty_gia, t.nguon FROM {{ ref('stg_frmacph_ty_gia') }} t
    WHERE t.loai_tien = cur.name AND (t.ngay IS NULL OR t.ngay <= p.payment_date)
    ORDER BY t.ngay DESC NULLS LAST
    LIMIT 1
) tg ON TRUE
LEFT JOIN LATERAL (     -- tỷ giá PHP ngày gần nhất ≤ ngày thu (T7/CN/lễ → ngày làm việc trước đó)
    SELECT t.ty_gia FROM {{ ref('stg_frmacph_ty_gia') }} t
    WHERE t.loai_tien = 'PHP' AND t.ngay <= p.payment_date
    ORDER BY t.ngay DESC
    LIMIT 1
) tgp ON TRUE
WHERE p.state = 'posted'
  AND p.brand_etl = 9
  AND p.partner_type = 'customer'
  AND p.payment_type IN ('inbound', 'outbound')
  AND p.payment_date >= '{{ var("ph_go_live_date", "2026-09-10") }}'::date
