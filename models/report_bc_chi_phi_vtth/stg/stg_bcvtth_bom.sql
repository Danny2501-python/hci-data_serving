-- =============================================================================
-- stg_bcvtth_bom
-- Định mức vật tư theo BOM cho từng dịch vụ trên phiếu phẫu thuật.
--
-- MATERIALIZED = table (override +materialized: ephemeral của cả folder):
-- đứng riêng chạy chỉ ~4.5s/737k dòng, nhưng nếu để ephemeral, dbt sẽ inline
-- toàn bộ CTE này vào chung 1 câu SQL khổng lồ với window function trên 1.78tr
-- dòng ở int_bcvtth_service_rate — khiến Postgres planner chọn plan rất tệ
-- (lần chạy thực tế: 41 phút rồi lỗi SSL connection closed). Vật lý hoá thành
-- bảng thật để có stats/plan riêng, JOIN vào mart nhanh và ổn định.
-- sh_surgery_bom_rel (form_id -> bom_id)
--   -> sh_medical_product_bundle (bom_id -> service_id: mỗi BOM gắn ĐÚNG 1
--      dịch vụ, không cần chia tỷ lệ như thực tế)
--   -> sh_medical_health_center_service (service_id -> product_id dịch vụ,
--      cùng id-space với service_product_id dùng xuyên suốt report này)
--   -> sh_medical_products_line (bom_id -> supply_id vật tư + số lượng định mức,
--      product_id ở bảng này là id vật tư theo bảng chi tiết nghiệp vụ, cùng
--      id-space với stag_his_form_supply_2.supply_id — ĐÃ VERIFY khớp trực
--      tiếp trên dữ liệu mẫu, không phải supply_product_id).
--
-- LƯU Ý: các bảng sh_medical_* này có id NỘI BỘ THEO TỪNG BRAND (mỗi brand 1
-- Odoo riêng, tự tăng id từ 1) — id có thể trùng số giữa các brand khác nhau
-- (đã verify: 16,870 id bundle và 118,311 id products_line bị trùng chéo
-- brand). BẮT BUỘC luôn JOIN kèm brand_etl, không được join chỉ theo id.
--
-- sh_medical_products_line có ~0.43% dòng trùng lặp nội dung
-- (bundle, product_id, quantity, brand_etl) do dữ liệu nguồn (2 dòng nguyên
-- liệu giống hệt nhau trong 1 công thức) — SUM(quantity) để cộng dồn, coi đây
-- là 2 lần dùng cùng 1 vật tư trong công thức thay vì loại bỏ trùng.
-- =============================================================================
{{ config(materialized='table') }}

WITH bom_line AS (
    SELECT
        bundle AS bom_id,
        product_id AS bom_supply_id,
        brand_etl,
        SUM(quantity) AS bom_qty
    FROM {{ source('dwh_public', 'sh_medical_products_line') }}
    GROUP BY bundle, product_id, brand_etl
),

bundle_service AS (
    SELECT
        b.id AS bom_id,
        b.brand_etl,
        s.product_id AS service_product_id
    FROM {{ source('dwh_public', 'sh_medical_product_bundle') }} b
    JOIN {{ source('dwh_public', 'sh_medical_health_center_service') }} s
        ON s.id = b.service_id AND s.brand_etl = b.brand_etl
)

-- Phòng trường hợp hiếm: 1 phiếu gắn 2 bom_id khác nhau nhưng cùng trỏ về 1
-- service_product_id (vd. 2 version BOM cho cùng dịch vụ) -> SUM để tránh
-- JOIN fan-out ở tầng mart thay vì làm trùng khoá/nhân đôi định mức.
SELECT
    r.surgery_id AS form_id,
    r.brand_etl,
    bs.service_product_id,
    bl.bom_supply_id,
    SUM(bl.bom_qty) AS bom_qty
FROM {{ source('dwh_public', 'sh_surgery_bom_rel') }} r
JOIN bundle_service bs
    ON bs.bom_id = r.bom_id AND bs.brand_etl = r.brand_etl
JOIN bom_line bl
    ON bl.bom_id = r.bom_id AND bl.brand_etl = r.brand_etl
GROUP BY r.surgery_id, r.brand_etl, bs.service_product_id, bl.bom_supply_id
