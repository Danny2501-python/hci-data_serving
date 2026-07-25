-- =============================================================================
-- stg_bcvtth_supply_cost
-- Giá trị (tiền) xuất kho thực tế của vật tư, theo phiếu xuất kho (picking_id)
-- + sản phẩm vật tư (supply_product_id). Nối stock_move -> stock_valuation_layer
-- qua stock_move_id. Không cần stock_move_line: đã verify
-- stock_move.product_qty = SUM(stock_move_line.qty_done) khớp tuyệt đối.
-- =============================================================================
WITH valuation AS (
    SELECT
        stock_move_id,
        SUM(value) AS value_total
    FROM {{ source('dwh_public', 'stock_valuation_layer') }}
    GROUP BY stock_move_id
)

SELECT
    sm.picking_id,
    sm.product_id AS supply_product_id,
    sm.brand_etl,
    ABS(v.value_total) AS supply_cost_value
FROM {{ source('dwh_public', 'stock_move') }} sm
JOIN valuation v ON v.stock_move_id = sm.id
