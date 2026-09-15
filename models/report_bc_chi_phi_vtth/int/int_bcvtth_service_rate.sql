-- =============================================================================
-- int_bcvtth_service_rate
-- Tỷ lệ phân bổ vật tư theo dịch vụ.
-- Nhóm "1 lần xuất vật tư" = form_supply_id (khoá của 1 dòng gốc trong union
-- stag_his_supply trước khi fan-out theo dịch vụ) — 1 vật tư gắn N dịch vụ đã
-- fan-out sẵn thành N dòng cùng form_supply_id + qty_used ở stg_bcvtth_form_supply.
-- LƯU Ý: không được dùng (supply_id, supply_product_id, picking_id, qty_used)
-- làm khoá nhóm — đã verify có ~95 cặp form_supply_id KHÁC NHAU nhưng trùng
-- giá trị 4 cột này (2 lần xuất vật tư thật sự khác nhau, trùng ngẫu nhiên),
-- dùng khoá đó sẽ gộp nhầm 2 nhóm fan-out và làm sai lệch tổng tiền phân bổ.
-- Trong mỗi nhóm:
--   - Nếu tổng doanh thu các dịch vụ > 0: chia theo tỷ lệ doanh thu.
--   - Nếu tổng doanh thu = 0 (hoặc NULL): chia đều theo số dịch vụ trong nhóm.
-- Nhóm chỉ có 1 dịch vụ -> rate = 1 (100%) tự nhiên theo đúng công thức trên.
--
-- MATERIALIZED = table: đồng bộ với các model khác trong pipeline này để
-- tránh bị inline vào query tổng (xem lý do chi tiết ở stg_bcvtth_bom).
-- =============================================================================
{{ config(materialized='table') }}

WITH svc_revenue AS (
    -- MAX(revenue/product): 1 dịch vụ có thể có nhiều dòng doanh thu khác
    -- nhau trên cùng phiếu (vd. đặt lại/đổi dòng dịch vụ với giá khác) vì
    -- report_kpi_team_service không có order_product_id để phân biệt dòng
    -- gốc; lấy 1 giá trị đại diện để tránh JOIN fan-out gây trùng khoá.
    SELECT form_id, brand_etl, product_id, MAX(product) AS service_name, MAX(revenue) AS revenue, room, product_category, surgery_type
    FROM {{ ref('stg_bcvtth_team_service') }}
    GROUP BY form_id, brand_etl, product_id, room, product_category, surgery_type
),

base AS (
    SELECT
        s.*,
        r.service_name,
        r.revenue,
        r.room,
        r.product_category,
        r.surgery_type
    FROM {{ ref('int_bcvtth_supply_with_cost') }} s
    LEFT JOIN svc_revenue r
        ON r.form_id = s.form_id
       AND r.brand_etl = s.brand_etl
       AND r.product_id = s.service_product_id
),

grp AS (
    SELECT
        *,
        SUM(COALESCE(revenue, 0)) OVER (
            PARTITION BY form_supply_id, form_id, brand_etl
        ) AS group_revenue,
        COUNT(*) OVER (
            PARTITION BY form_supply_id, form_id, brand_etl
        ) AS group_n_service
    FROM base
)

SELECT
    *,
    CASE
        WHEN group_revenue > 0 THEN COALESCE(revenue, 0) / group_revenue
        ELSE 1.0 / group_n_service
    END AS service_rate
FROM grp
