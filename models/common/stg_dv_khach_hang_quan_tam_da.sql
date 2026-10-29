{{
  config(
    materialized = 'ephemeral'
  )
}}

-- =============================================================================
-- stg_dv_khach_hang_quan_tam_da — bản ĐÔNG Á (brand_etl = 2) của
-- stg_dv_khach_hang_quan_tam. Logic giữ nguyên: dịch vụ KH quan tâm = cline
-- tạo sớm nhất của booking (tie-break theo cline_id).
--
-- Khác bản Kangnam: stag_sources join brand_id = 1 vì Đông Á dùng chung danh
-- mục nguồn (source_id) với Kangnam, stag_sources không có brand 2.
-- =============================================================================

WITH cline AS (
    SELECT
        cl.id AS crm_id,
        cl.code_customer,
        cln.brand_etl,
        cln.id AS cline_id,
        cln.stage,
        ss.source AS source,
        ss.category_source_code,
        CASE
            WHEN cl.customer_come = 'yes' THEN cl.arrival_date + interval '7 hours'
            ELSE cl.booking_date + interval '7 hours'
        END AS booking_report_date,
        cln.create_date + interval '7 hours' AS cline_created_date,
        sp.product_group,
        sp.product_category
    FROM {{ source('crm_base', 'crm_line') }} cln
        LEFT JOIN {{ source('crm_base', 'crm_lead') }} cl
               ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
        LEFT JOIN {{ source('crm_base', 'stag_sources') }} ss
               ON ss.old_id = cl.source_id AND ss.brand_id = 1
        LEFT JOIN {{ source('crm_base', 'view_stag_products') }} sp
               ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
    WHERE cln.brand_etl = 2
),
cline_rank AS (
    SELECT cl.*,
           ROW_NUMBER() OVER (PARTITION BY cl.crm_id ORDER BY cl.cline_created_date, cl.cline_id) AS cus_bk_line_order
    FROM cline cl
)
SELECT
    cr.crm_id,
    cr.code_customer,
    cr.source,
    cr.category_source_code,
    cr.brand_etl,
    cr.booking_report_date,
    cr.product_group    AS first_product_group,
    cr.product_category AS first_product_category
FROM cline_rank cr
WHERE cr.cus_bk_line_order = 1
