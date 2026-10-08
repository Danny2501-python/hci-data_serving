{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_vat_tu — chi phí VẬT TƯ TIÊU HAO ERP PH (giá trị xuất kho), 1 dòng / lớp định giá.
-- Cách tính giống Kangnam (report_bc_chi_phi_vtth): giá trị = stock_valuation_layer.value
-- của stock_move. Chỉ lấy dòng đi qua ranh giới kho nội bộ:
--   internal -> production / customer / inventory : xuất dùng / bán / hao hụt  -> chi phí (+)
--   production / customer / inventory -> internal : trả lại kho                -> giảm chi phí (-)
--   (nhập mua từ NCC, chuyển giữa các kho nội bộ: KHÔNG phải chi phí -> bỏ)
-- ERP SUN nhân bản từ Kangnam -> bảng kho mang theo lịch sử Kangnam: BẮT BUỘC lọc
-- ngày ≥ var('ph_go_live_date') và brand_etl = 9. Ngày = create_date (UTC) + 8 giờ (Manila).
--
-- ĐƠN VỊ TIỀN – công tắc var('ph_vat_tu_don_vi') (mặc định 'VND'):
--   [2026-10-08] Công ty trong ERP PH dùng PHP (bút toán sổ kho 922 ghi PHP) nhưng GIÁ VỐN
--   vật tư đang là số VND sao nguyên từ ERP Kangnam (vd khẩu trang 576, bơm tiêm 5ml 735,
--   Profhilo 5.194.444 / hộp) -> 'VND' = lấy nguyên số làm VND.
--   Khi đội ERP sửa giá vốn sang PHP: đặt ph_vat_tu_don_vi: PHP -> quy đổi theo
--   stg_frmacph_ty_gia (tỷ giá PHP ngày gần nhất ≤ ngày xuất).
-- =============================================================================
{%- set don_vi = var('ph_vat_tu_don_vi', 'VND') %}
{%- if don_vi not in ['VND', 'PHP'] %}
  {{ exceptions.raise_compiler_error("ph_vat_tu_don_vi phải là 'VND' hoặc 'PHP', đang là: " ~ don_vi) }}
{%- endif %}
WITH vt AS (
    SELECT
        v.id                                          AS svl_id,
        (v.create_date + interval '8 hours')::date    AS ngay,
        v.company_id,
        sm.reference                                  AS ma_chung_tu,
        pt.name                                       AS vat_tu,
        ls.usage                                      AS tu_kho,
        ld.usage                                      AS den_kho,
        -v.quantity                                   AS so_luong,      -- xuất dùng = dương
        -v.value                                      AS gia_tri_goc    -- chi phí dương, trả lại âm
    FROM {{ source('ph', 'stock_valuation_layer') }} v
    JOIN {{ source('ph', 'stock_move') }}            sm ON sm.id = v.stock_move_id
    LEFT JOIN {{ source('ph', 'stock_location') }}   ls ON ls.id = sm.location_id
    LEFT JOIN {{ source('ph', 'stock_location') }}   ld ON ld.id = sm.location_dest_id
    LEFT JOIN {{ source('ph', 'product_product') }}  pp ON pp.id = v.product_id
    LEFT JOIN {{ source('ph', 'product_template') }} pt ON pt.id = pp.product_tmpl_id
    WHERE v.brand_etl = 9
      AND (v.create_date + interval '8 hours')::date >= '{{ var("ph_go_live_date", "2026-09-10") }}'::date
      AND (   (ls.usage = 'internal' AND ld.usage IN ('production', 'customer', 'inventory'))
           OR (ld.usage = 'internal' AND ls.usage IN ('production', 'customer', 'inventory')))
)
SELECT
    vt.*,
    '{{ don_vi }}'::text                              AS loai_tien_goc,
{%- if don_vi == 'VND' %}
    1::numeric                                        AS ty_gia,
    'VND'::text                                       AS nguon_ty_gia,
    round(vt.gia_tri_goc)                             AS chi_phi_vnd
FROM vt
{%- else %}
    tg.ty_gia,
    coalesce(tg.nguon, 'THIEU_TY_GIA')                AS nguon_ty_gia,
    round(vt.gia_tri_goc * tg.ty_gia)                 AS chi_phi_vnd
FROM vt
LEFT JOIN LATERAL (
    SELECT t.ty_gia, t.nguon FROM {{ ref('stg_frmacph_ty_gia') }} t
    WHERE t.loai_tien = 'PHP' AND (t.ngay IS NULL OR t.ngay <= vt.ngay)
    ORDER BY t.ngay DESC NULLS LAST
    LIMIT 1
) tg ON TRUE
{%- endif %}
