-- =============================================================================
-- mart_report_bc_chi_phi_vtth
-- Báo cáo vật tư tiêu hao phân bổ theo bác sĩ mổ chính x dịch vụ, kèm định
-- mức BOM để so sánh với số thực tế.
--
-- THỰC TẾ: allocated_qty / allocated_cost_value = qty_used / supply_cost_value
-- gốc nhân với service_rate (phân bổ theo doanh thu dịch vụ, vì 1 vật tư có
-- thể gắn nhiều dịch vụ) x doctor_rate (chia đều theo số bác sĩ mổ chính CỦA
-- CHÍNH dịch vụ đó, không phải toàn phiếu).
--
-- ĐỊNH MỨC (BOM): bom_qty lấy từ sh_medical_products_line theo đúng
-- (form_id, service_product_id, supply_id) — KHÔNG cần nhân service_rate vì
-- mỗi BOM đã gắn cố định với đúng 1 dịch vụ (không có khái niệm "1 vật tư
-- định mức cho nhiều dịch vụ" như thực tế); chỉ nhân doctor_rate để chia đều
-- cho các bác sĩ của dịch vụ đó, cùng logic với thực tế. Đơn giá dùng để quy
-- đổi bom_qty ra tiền lấy TỪ CHÍNH dòng thực tế tương ứng
-- (supply_cost_value / qty_used của cùng form_supply_id) để đơn giá định mức
-- và thực tế nhất quán — nếu dòng đó không có qty_used/cost (chưa xuất kho)
-- thì bom_cost_value sẽ NULL.
--
-- LƯU Ý: nếu 1 (form_id, service_product_id, supply_id) có NHIỀU dòng thực
-- tế (vd. cùng 1 vật tư được xuất 2 lần cho cùng dịch vụ đó), bom_qty gốc sẽ
-- LẶP LẠI giống nhau trên từng dòng (vì định mức là 1 con số cố định cho cả
-- form+dịch vụ+vật tư, không chia theo số lần xuất) — khi cần so sánh tổng
-- định mức vs tổng thực tế phải lấy định mức 1 lần duy nhất theo nhóm
-- (form_id, service_product_id, supply_id), không được SUM trực tiếp
-- bom_allocated_qty như với allocated_qty.
--
-- JOIN doctor_rate theo cả service_product_id -> dịch vụ nào không có BS mổ
-- chính/mổ phụ sẽ không có dòng output tương ứng (INNER JOIN).
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
    s.room,
    s.product_category,
    s.surgery_type,
    s.service_name,
    s.revenue AS service_revenue,
    s.service_rate,
    d.employee_id,
    d.employee AS doctor_name,
    d.doctor_rate,
    s.qty_used * s.service_rate * d.doctor_rate AS allocated_qty,
    s.supply_cost_value * s.service_rate * d.doctor_rate AS allocated_cost_value,
    b.bom_qty,
    b.bom_qty * d.doctor_rate AS bom_allocated_qty,
    b.bom_qty * (s.supply_cost_value / NULLIF(s.qty_used, 0)) AS bom_cost_value,
    b.bom_qty * (s.supply_cost_value / NULLIF(s.qty_used, 0)) * d.doctor_rate AS bom_allocated_cost_value
FROM {{ ref('int_bcvtth_service_rate') }} s
JOIN {{ ref('int_bcvtth_doctor_rate') }} d
    ON d.form_id = s.form_id
   AND d.brand_etl = s.brand_etl
   AND d.service_product_id = s.service_product_id
LEFT JOIN {{ ref('stg_bcvtth_bom') }} b
    ON b.form_id = s.form_id
   AND b.brand_etl = s.brand_etl
   AND b.service_product_id = s.service_product_id
   AND b.bom_supply_id = s.supply_id
