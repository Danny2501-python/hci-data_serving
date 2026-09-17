-- =============================================================================
-- int_bcvtth_supply_with_cost
-- Ghép giá trị tiền vào từng dòng vật tư tiêu hao.
--
-- MATERIALIZED = table: đồng bộ với các model khác trong pipeline này để
-- tránh bị inline vào query tổng (xem lý do chi tiết ở stg_bcvtth_bom).
-- =============================================================================
{{ config(materialized='table') }}

SELECT
    fs.*,
    COALESCE(sc.supply_cost_value, 0) AS supply_cost_value
FROM {{ ref('stg_bcvtth_form_supply') }} fs
LEFT JOIN {{ ref('stg_bcvtth_supply_cost') }} sc
    ON sc.picking_id = fs.picking_id
   AND sc.supply_product_id = fs.supply_product_id
   AND sc.brand_etl = fs.brand_etl
