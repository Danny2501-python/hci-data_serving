-- =============================================================================
-- stg_bcvtth_team_service
-- Dịch vụ + doanh thu + nhân sự thực hiện theo phiếu, dùng để tính tỷ lệ phân
-- bổ vật tư theo dịch vụ (revenue) và xác định bác sĩ mổ chính (roleid = 1) /
-- bác sĩ mổ phụ (roleid = 2, dùng fallback).
-- revenue ổn định theo (form_id, product_id) — MAX chỉ để khử trùng lặp do
-- report_kpi_team_service có nhiều dòng theo từng nhân sự thực hiện.
-- =============================================================================
SELECT
    form_id,
    brand_etl,
    product_id,
    roleid,
    employee_id,
    employee,
    MAX(revenue) AS revenue
FROM {{ source('dwh_public', 'report_kpi_team_service') }}
GROUP BY form_id, brand_etl, product_id, roleid, employee_id, employee
