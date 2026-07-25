-- =============================================================================
-- mart_report_bc_chi_phi_vtth
-- Báo cáo vật tư tiêu hao phân bổ theo bác sĩ mổ chính x dịch vụ.
-- allocated_qty / allocated_cost_value = qty_used / supply_cost_value gốc
-- nhân với service_rate (phân bổ theo doanh thu dịch vụ) x doctor_rate
-- (chia đều theo số bác sĩ mổ chính CỦA CHÍNH dịch vụ đó, không phải toàn
-- phiếu). JOIN doctor_rate theo cả service_product_id -> dịch vụ nào không có
-- BS mổ chính/mổ phụ sẽ không có dòng output tương ứng (INNER JOIN).
-- =============================================================================
SELECT
    s.form_id,
    s.brand_etl,
    s.form_supply_id,
    s.walkinid,
    s.crm_id,
    s.booking,
    s.code_customer,
    s.contact_name,
    s.company,
    s.company_id,
    s.services_date,
    s.supply_category,
    s.supply,
    s.supply_id,
    s.supply_product_id,
    s.uom,
    s.qty_used,
    s.supply_cost_value,
    s.service_product_id,
    s.revenue AS service_revenue,
    s.service_rate,
    d.employee_id,
    d.employee AS doctor_name,
    d.doctor_rate,
    s.qty_used * s.service_rate * d.doctor_rate AS allocated_qty,
    s.supply_cost_value * s.service_rate * d.doctor_rate AS allocated_cost_value
FROM {{ ref('int_bcvtth_service_rate') }} s
JOIN {{ ref('int_bcvtth_doctor_rate') }} d
    ON d.form_id = s.form_id
   AND d.brand_etl = s.brand_etl
   AND d.service_product_id = s.service_product_id
