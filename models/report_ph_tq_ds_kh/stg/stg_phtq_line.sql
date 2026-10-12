{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_phtq_line — 1 dòng / dòng dịch vụ (crm_line) ERP PH (schema ph, brand 9) kèm thông
-- tin sản phẩm. Thay cho stag_products của Kangnam (public.stag_products / stag_sources
-- KHÔNG có brand 9 – chỉ brand 0,1,3,4).
-- rn_lead = 1: dòng dịch vụ đầu tiên của lead – dùng gán dịch vụ cho phiếu thu (ERP PH
-- gắn phiếu thu theo lead, không theo dòng dịch vụ như stag_payment_transfer của KN).
-- =============================================================================
SELECT
    cl.id                                                   AS line_id,
    cl.crm_id                                               AS lead_id,
    cl.stage                                                AS line_tt,
    cl.total_received                                       AS tong_tien_line,
    cl.quantity,
    cl.number_used,
    cl.his_service_type,
    pt.default_code                                         AS code_dv,
    pt.name                                                 AS ten_dv,
    pc.name                                                 AS nhom_dv,
    row_number() OVER (PARTITION BY cl.crm_id ORDER BY cl.id) AS rn_lead
FROM {{ source('ph', 'crm_line') }} cl
LEFT JOIN {{ source('ph', 'product_product') }}  pp ON pp.id = cl.product_id
LEFT JOIN {{ source('ph', 'product_template') }} pt ON pt.id = pp.product_tmpl_id
LEFT JOIN {{ source('ph', 'product_category') }} pc ON pc.id = pt.categ_id
