{{
  config(
    materialized = 'view',
    alias        = 'view_stag_crm_line_cross_sale'
  )
}}
-- =============================================================================
-- view_stag_crm_line_cross_sale
-- Backup logic từ view cũ trên sandbox (staging_sci @ 10.10.10.226) vào dbt để
-- có chỗ tra cứu lại nếu sau này bị mất/sửa nhầm ở nguồn. Sandbox là bản lưu
-- tĩnh (dbt không chạy ở đó) nên không có rủi ro DROP CASCADE, nhưng đưa vào
-- dbt/git để có version control + không phụ thuộc 1 bản duy nhất trên sandbox.
-- Logic giữ NGUYÊN VẸN so với view gốc, chỉ thay tên bảng thô bằng macro
-- source()/ref(), không sửa bất kỳ điều kiện lọc nào.
-- =============================================================================

 WITH __dbt__cte__stg_booking_id_co_tien_tc AS (
         SELECT spt.crm_id,
            spt.brand_etl,
            sum(spt.payment) AS total_payment
           FROM {{ ref('stag_payment_transfer') }} spt
             LEFT JOIN {{ source('ovs_source', 'crm_lead') }} cl ON cl.id = spt.crm_id AND cl.brand_etl = spt.brand_etl
          WHERE cl.stage_id = 4
          GROUP BY spt.crm_id, spt.brand_etl
         HAVING sum(spt.payment) > 0::numeric
        ), cline AS (
         SELECT cl.id AS crm_id,
            cl.code_customer,
            cln.brand_etl,
            cln.id AS cline_id,
            cln.stage,
                CASE
                    WHEN cl.customer_come::text = 'yes'::text THEN cl.arrival_date + '07:00:00'::interval
                    ELSE cl.booking_date + '07:00:00'::interval
                END AS booking_report_date,
            cln.create_date + '07:00:00'::interval AS cline_created_date,
            spt.payment_date AS cline_payment_date,
                CASE
                    WHEN sp.his_service_type::text = 'Surgery'::text THEN 'PTTM'::text
                    WHEN sp.his_service_type::text = ANY (ARRAY['Spa'::character varying, 'Laser'::character varying, 'Card'::character varying]::text[]) THEN 'Beauty & Spa'::text
                    WHEN sp.his_service_type::text = 'Odontology'::text THEN 'Nha khoa'::text
                    WHEN sp.his_service_type::text = 'wellness'::text THEN 'Wellness'::text
                    WHEN sp.his_service_type::text = 'weight_loss'::text THEN 'Weight Loss'::text
                    ELSE 'Khác'::text
                END AS business_line
           FROM {{ source('ovs_source', 'crm_line') }} cln
             LEFT JOIN {{ source('ovs_source', 'crm_lead') }} cl ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
             LEFT JOIN {{ ref('stag_payment_transfer') }} spt ON spt.clineid = cln.id AND spt.brand_etl = cln.brand_etl
             LEFT JOIN {{ ref('view_stag_products') }} sp ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
          WHERE (cl.id IN ( SELECT __dbt__cte__stg_booking_id_co_tien_tc.crm_id
                   FROM __dbt__cte__stg_booking_id_co_tien_tc))
        ), rnk_bl_cline AS (
         SELECT cln.crm_id,
            cln.code_customer,
            cln.brand_etl,
            cln.cline_id,
            cln.stage,
            cln.booking_report_date,
            cln.cline_created_date,
            cln.cline_payment_date,
            cln.business_line,
            row_number() OVER (PARTITION BY cln.business_line, cln.code_customer ORDER BY cln.cline_created_date) AS cus_bl_cline_order,
            row_number() OVER (PARTITION BY cln.crm_id ORDER BY cln.cline_created_date) AS crm_cline_order,
            row_number() OVER (PARTITION BY cln.code_customer ORDER BY cln.cline_created_date) AS cus_cline_order
           FROM cline cln
          WHERE cln.brand_etl = 1 AND cln.booking_report_date >= '2026-06-01 00:00:00'::timestamp without time zone
        ), labeling_1 AS (
         SELECT rbc.crm_id,
            rbc.code_customer,
            rbc.brand_etl,
            rbc.cline_id,
            rbc.stage,
            rbc.booking_report_date,
            rbc.cline_created_date,
            rbc.cline_payment_date,
            rbc.business_line,
            rbc.cus_bl_cline_order,
            rbc.crm_cline_order,
            rbc.cus_cline_order,
            rbc.cus_cline_order = 1 AS is_main_service,
            rbc.crm_cline_order = 1 AS is_main_service_bk,
                CASE
                    WHEN prev_rbc.cline_payment_date IS NULL THEN false
                    ELSE rbc.cline_payment_date > (prev_rbc.cline_payment_date + '6 mons'::interval)
                END AS is_line_over_6_months_in_bl,
            first_value(rbc.business_line) OVER (PARTITION BY rbc.code_customer ORDER BY rbc.cline_created_date) AS main_bl_customer,
            first_value(rbc.business_line) OVER (PARTITION BY rbc.crm_id ORDER BY rbc.cline_created_date) AS main_bl_bk
           FROM rnk_bl_cline rbc
             LEFT JOIN rnk_bl_cline prev_rbc ON prev_rbc.cus_bl_cline_order = (rbc.cus_bl_cline_order - 1) AND prev_rbc.code_customer::text = rbc.code_customer::text AND prev_rbc.business_line = rbc.business_line
        )
 SELECT lb.crm_id,
    lb.code_customer,
    lb.brand_etl,
    lb.cline_id,
    lb.stage,
    lb.booking_report_date,
    lb.cline_created_date,
    lb.cline_payment_date,
    lb.business_line,
    lb.cus_bl_cline_order,
    lb.crm_cline_order,
    lb.cus_cline_order,
    lb.is_main_service,
    lb.is_main_service_bk,
    lb.is_line_over_6_months_in_bl,
    lb.main_bl_customer,
    lb.main_bl_bk,
        CASE
            WHEN lb.is_main_service = true THEN false
            WHEN lb.is_main_service = false AND lb.cus_bl_cline_order = 1 AND lb.business_line <> lb.main_bl_customer AND (lb.stage::text = ANY (ARRAY['processing'::character varying, 'done'::character varying]::text[])) THEN true
            WHEN lb.is_main_service = false AND lb.cus_bl_cline_order <> 1 AND lb.business_line <> lb.main_bl_customer AND lb.is_line_over_6_months_in_bl = true AND (lb.stage::text = ANY (ARRAY['processing'::character varying, 'done'::character varying]::text[])) THEN true
            WHEN lb.is_main_service = false AND lb.is_main_service_bk = false AND lb.business_line = lb.main_bl_customer AND lb.is_line_over_6_months_in_bl = true AND lb.business_line <> lb.main_bl_bk AND (lb.stage::text = ANY (ARRAY['processing'::character varying, 'done'::character varying]::text[])) THEN true
            ELSE false
        END AS is_cross_sale
   FROM labeling_1 lb
