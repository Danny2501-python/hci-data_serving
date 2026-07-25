-- =============================================================================
-- int_bcvtth_doctor_rate
-- Danh sách bác sĩ mổ chính theo TỪNG DỊCH VỤ trên phiếu (form_id + product_id
-- = service_product_id), roleid = 1. Nếu 1 dịch vụ có N bác sĩ mổ chính, chia
-- đều vật tư của dịch vụ đó cho N bác sĩ. Nếu dịch vụ không có BS mổ chính,
-- fallback sang BS mổ phụ (roleid = 2) của CHÍNH dịch vụ đó. Dịch vụ không có
-- cả 2 vai trò này sẽ không xuất hiện ở đây -> phần vật tư phân bổ cho dịch vụ
-- đó bị loại khỏi report ở tầng mart (không có bác sĩ để gán).
-- =============================================================================
WITH r1 AS (
    SELECT form_id, brand_etl, product_id AS service_product_id, employee_id, MAX(employee) AS employee
    FROM {{ ref('stg_bcvtth_team_service') }}
    WHERE roleid = 1
    GROUP BY form_id, brand_etl, product_id, employee_id
),

r2 AS (
    SELECT form_id, brand_etl, product_id AS service_product_id, employee_id, MAX(employee) AS employee
    FROM {{ ref('stg_bcvtth_team_service') }}
    WHERE roleid = 2
    GROUP BY form_id, brand_etl, product_id, employee_id
),

service_has_r1 AS (
    SELECT DISTINCT form_id, brand_etl, service_product_id FROM r1
),

doctor AS (
    SELECT * FROM r1

    UNION ALL

    SELECT r2.*
    FROM r2
    LEFT JOIN service_has_r1 h
        ON h.form_id = r2.form_id
       AND h.brand_etl = r2.brand_etl
       AND h.service_product_id = r2.service_product_id
    WHERE h.form_id IS NULL
)

SELECT
    *,
    1.0 / COUNT(*) OVER (PARTITION BY form_id, brand_etl, service_product_id) AS doctor_rate
FROM doctor
