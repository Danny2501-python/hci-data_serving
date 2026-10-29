{{
  config(
    materialized = 'ephemeral'
  )
}}

-- =============================================================================
-- stg_booking_nhom_dich_vu_chinh_da — bản ĐÔNG Á (brand_etl = 2) của
-- stg_booking_nhom_dich_vu_chinh. Logic giữ nguyên: nhóm dịch vụ chính của
-- booking = product_group của cline có id nhỏ nhất.
-- =============================================================================

SELECT DISTINCT ON (cl.id)
    cl.id AS crm_id,
    cln.brand_etl,
    sp.product_group AS nhom_dich_vu_chinh,
    sp.product_ctg_id AS product_category_id,
    sp.his_service_type,
    CASE
        WHEN sp.his_service_type = 'Surgery' THEN 'PTTM'
        WHEN sp.his_service_type IN ('Spa', 'Laser', 'Card') THEN 'Beauty & Spa'
        WHEN sp.his_service_type = 'Odontology' THEN 'Nha khoa'
        WHEN sp.his_service_type = 'wellness' THEN 'Wellness'
        WHEN sp.his_service_type = 'weight_loss' THEN 'Weight Loss'
        WHEN sp.his_service_type IS NOT NULL THEN 'Khác'
        ELSE NULL
    END AS business_line
FROM {{ source('crm_base', 'crm_line') }} cln
    LEFT JOIN {{ source('crm_base', 'crm_lead') }} cl
           ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
    LEFT JOIN {{ source('crm_base', 'view_stag_products') }} sp
           ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
WHERE cln.brand_etl = 2
ORDER BY cl.id, cln.id
