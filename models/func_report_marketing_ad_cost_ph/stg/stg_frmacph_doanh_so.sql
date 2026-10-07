{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_doanh_so — doanh số ERP PH = phiếu thu đã ghi sổ (state = 'posted').
-- Phiếu thu có nhiều loại tiền (PHP/VND/USD/AUD) → dùng amount_vnd (đã quy đổi).
-- inbound cộng, outbound (hoàn tiền) trừ.
-- =============================================================================
SELECT
    p.id                                                    AS payment_id,
    p.crm_id                                                AS lead_id,
    p.payment_date                                          AS ngay,
    CASE WHEN p.payment_type = 'outbound' THEN -1 ELSE 1 END
      * coalesce(p.amount_vnd, p.amount)                    AS doanh_so,
    co.name                                                 AS chi_nhanh
FROM {{ source('ph', 'account_payment') }} p
LEFT JOIN {{ source('ph', 'm_res_company') }} co ON co.id = p.company_id
WHERE p.state = 'posted'
