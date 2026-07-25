-- =============================================================================
-- stg_bcvtth_team_service
-- Dịch vụ + doanh thu + nhân sự thực hiện theo phiếu, dùng để tính tỷ lệ phân
-- bổ vật tư theo dịch vụ (revenue) và xác định bác sĩ mổ chính (roleid = 1) /
-- bác sĩ mổ phụ (roleid = 2, dùng fallback).
-- revenue ổn định theo (form_id, product_id) — MAX chỉ để khử trùng lặp do
-- report_kpi_team_service có nhiều dòng theo từng nhân sự thực hiện.
--
-- MATERIALIZED = table: model này được REF 3 LẦN trong pipeline (1 lần ở
-- int_bcvtth_service_rate, 2 lần ở int_bcvtth_doctor_rate r1/r2) — nếu để
-- ephemeral, dbt sẽ inline GROUP BY trên report_kpi_team_service (2.18tr
-- dòng, không có index) 3 LẦN riêng biệt trong cùng 1 câu SQL cuối. Đứng
-- riêng chỉ mất ~4s, nhưng lặp x3 + kết hợp window function khác đẩy tổng
-- query lên rất chậm (cùng nguyên nhân đã fix ở stg_bcvtth_bom).
-- =============================================================================
{{ config(materialized='table') }}

SELECT
    form_id,
    brand_etl,
    product_id,
    roleid,
    employee_id,
    employee,
    MAX(product) AS product,
    MAX(revenue) AS revenue
FROM {{ source('dwh_public', 'report_kpi_team_service') }}
GROUP BY form_id, brand_etl, product_id, roleid, employee_id, employee
