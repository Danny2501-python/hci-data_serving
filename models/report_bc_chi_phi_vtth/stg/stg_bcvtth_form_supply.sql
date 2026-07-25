-- =============================================================================
-- stg_bcvtth_form_supply
-- Vật tư tiêu hao của phiếu phẫu thuật (surgery). Mỗi dòng đã fan-out sẵn theo
-- dịch vụ (service_product_id) qua sh_surgery_supply_service_rel trong
-- stag_his_supply — 1 vật tư gắn N dịch vụ thì đã tách sẵn N dòng cùng qty_used.
-- =============================================================================
SELECT
    form_supply_id,
    form_id,
    brand_etl,
    data_union,
    walkinid,
    crm_id,
    booking,
    code_customer,
    contact_name,
    company,
    company_id,
    services_date,
    supply_category,
    supply,
    supply_id,
    supply_product_id,
    uom,
    qty_used,
    picking_id,
    product_id AS service_product_id
FROM {{ ref('mart_shs_form_supply') }}
WHERE data_union = 'surgery'
