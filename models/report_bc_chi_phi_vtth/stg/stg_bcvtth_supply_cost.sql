-- =============================================================================
-- stg_bcvtth_supply_cost
-- Giá trị (tiền) xuất kho thực tế của vật tư, theo phiếu xuất kho (picking_id)
-- + sản phẩm vật tư (supply_product_id). Nối stock_move -> stock_valuation_layer
-- qua stock_move_id. Không cần stock_move_line: đã verify
-- stock_move.product_qty = SUM(stock_move_line.qty_done) khớp tuyệt đối.
--
-- LƯU Ý QUAN TRỌNG: `stock_valuation_layer.id` (và các id nội bộ khác) KHÔNG
-- unique toàn cục — mỗi brand_etl có Odoo riêng, tự tăng id từ 1, nên
-- `stock_move_id` (FK trỏ vào stock_move.id) có thể trùng số giữa 2 brand
-- khác nhau (đã verify: 416 giá trị stock_move_id bị trùng giữa các cặp
-- brand_etl (1,3,4,8) — có cả brand_etl=1 là brand duy nhất report này dùng).
-- Phải GROUP BY + JOIN kèm brand_etl, nếu không SUM(value) sẽ cộng nhầm tiền
-- của brand khác vào.
--
-- MATERIALIZED = table: đồng bộ với các model khác trong pipeline này để
-- tránh bị inline vào query tổng (xem lý do chi tiết ở stg_bcvtth_bom).
-- =============================================================================
{{ config(materialized='table') }}

WITH valuation AS (
    SELECT
        stock_move_id,
        brand_etl,
        SUM(value) AS value_total
    FROM {{ source('dwh_public', 'stock_valuation_layer') }}
    GROUP BY stock_move_id, brand_etl
)

SELECT
    sm.picking_id,
    sm.product_id AS supply_product_id,
    sm.brand_etl,
    ABS(v.value_total) AS supply_cost_value
FROM {{ source('dwh_public', 'stock_move') }} sm
JOIN valuation v
    ON v.stock_move_id = sm.id
   AND v.brand_etl = sm.brand_etl
