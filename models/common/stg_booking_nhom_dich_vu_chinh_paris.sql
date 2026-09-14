{{
  config(
    materialized = 'ephemeral'
  )
}}

-- Bản Paris (brand_etl = 3) của stg_booking_nhom_dich_vu_chinh.sql (bản gốc
-- chỉ tính brand_etl = 1 - Kangnam, tự document rõ "theo đúng quy ước chung
-- của các model trong common/ - chỉ tính Kangnam"). Logic giữ nguyên y hệt
-- bản KN: cline có cln.id NHỎ NHẤT trong booking, nhom_dich_vu_chinh =
-- view_stag_products.product_group (nhãn đã bake sẵn, dùng chung toàn hệ
-- thống). Đổi source('crm_base', ...) sang source('paris', ...) cho nhất
-- quán với cách func_report_marketing_ad_cost_pr khai báo nguồn.

SELECT DISTINCT ON (cl.id)
    cl.id AS crm_id,
    cln.brand_etl,
    sp.product_group AS nhom_dich_vu_chinh,
    sp.product_ctg_id AS product_category_id,
    sp.his_service_type,
    CASE
        WHEN sp.his_service_type = 'Surgery' then 'PTTM'
        WHEN sp.his_service_type IN ('Spa','Laser','Card') then 'Beauty & Spa'
        WHEN sp.his_service_type = 'Odontology' then 'Nha khoa'
        WHEN sp.his_service_type = 'wellness' then 'Wellness'
        WHEN sp.his_service_type = 'weight_loss' then 'Weight Loss'
        WHEN sp.his_service_type IS NOT NULL then 'Khác'
        ELSE NULL
    END as business_line
FROM {{ source('paris', 'crm_line') }} cln
    LEFT JOIN {{ source('paris', 'crm_lead') }} cl ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
    LEFT JOIN {{ source('paris', 'view_stag_products') }} sp ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
WHERE cln.brand_etl = 3
ORDER BY cl.id, cln.id
