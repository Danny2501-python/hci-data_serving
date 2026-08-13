{{
  config(
    materialized = 'view',
    alias        = 'view_kn_change_source'
  )
}}
-- =============================================================================
-- view_kn_change_source
-- Backup logic từ view cũ trên sandbox (staging_sci @ 10.10.10.226) vào dbt để
-- có chỗ tra cứu lại nếu sau này bị mất/sửa nhầm ở nguồn. Sandbox là bản lưu
-- tĩnh (dbt không chạy ở đó) nên không có rủi ro DROP CASCADE, nhưng đưa vào
-- dbt/git để có version control + không phụ thuộc 1 bản duy nhất trên sandbox.
-- Logic giữ NGUYÊN VẸN so với view gốc, chỉ thay tên bảng thô bằng macro
-- source()/ref(), không sửa bất kỳ điều kiện lọc nào.
-- =============================================================================

 WITH d AS (
         SELECT a.rnk,
            a.type_data,
            a.id,
            a.field_desc,
            a.old_value_integer,
            a.old_value_char,
            a.new_value_integer,
            a.new_value_char,
            a.mail_message_id,
            a.write_uid,
            a.write_date,
            a.date_changed,
            a.booking_won_date,
            a.model,
            a.res_id,
            a.crm_id,
            a.status_bk,
            b.payment_date
           FROM ( WITH a AS (
                         SELECT row_number() OVER (PARTITION BY a_2.crm_id ORDER BY a_2.date_changed DESC) AS rnk,
                            a_2.type_data,
                            a_2.id,
                            a_2.field_desc,
                            a_2.old_value_integer,
                            a_2.old_value_char,
                            a_2.new_value_integer,
                            a_2.new_value_char,
                            a_2.mail_message_id,
                            a_2.write_uid,
                            a_2.write_date,
                            a_2.date_changed,
                            a_2.booking_won_date,
                            a_2.model,
                            a_2.res_id,
                            a_2.crm_id,
                            a_2.status_bk
                           FROM {{ source('ovs_source', 'stag_mail_message_erp') }} a_2
                          WHERE a_2.type_data = 'changed_source'::text AND a_2.date_changed::date >= '2025-01-01'::date
                        )
                 SELECT a_1.rnk,
                    a_1.type_data,
                    a_1.id,
                    a_1.field_desc,
                    a_1.old_value_integer,
                    a_1.old_value_char,
                    a_1.new_value_integer,
                    a_1.new_value_char,
                    a_1.mail_message_id,
                    a_1.write_uid,
                    a_1.write_date,
                    a_1.date_changed,
                    a_1.booking_won_date,
                    a_1.model,
                    a_1.res_id,
                    a_1.crm_id,
                    a_1.status_bk
                   FROM a a_1
                     LEFT JOIN {{ source('ovs_source', 'crm_lead') }} cl_1 ON cl_1.id = a_1.crm_id
                  WHERE a_1.rnk = 1 AND cl_1.type::text <> 'lead'::text) a
             LEFT JOIN {{ source('ovs_source', 'crm_lead') }} cl ON cl.id = a.crm_id
             JOIN LATERAL ( SELECT spt.payment_date,
                    spt.company_id
                   FROM {{ ref('stag_payment_transfer') }} spt
                  WHERE spt.crm_id = cl.id AND a.date_changed::date >= spt.payment_date
                  ORDER BY spt.payment_date DESC
                 LIMIT 1) b ON true
          WHERE cl.type::text <> 'lead'::text
        ), p AS (
         SELECT d.crm_id,
            rb.name AS brand,
            mrs.name AS company,
            cl.name AS booking,
            d.old_value_char,
            d.new_value_char,
            d.date_changed::date AS date_changed,
            sp.product,
            b.ma_phieu,
            b.payment,
            b.payment_date,
            b.company_id,
            b.id,
            b.clineid,
            sp.product_category
           FROM d
             JOIN LATERAL ( SELECT spt.id,
                    spt.ma_phieu,
                    spt.payment_date,
                    spt.payment,
                    spt.product_id,
                    spt.company_id,
                    spt.clineid
                   FROM {{ ref('stag_payment_transfer') }} spt
                  WHERE spt.crm_id = d.crm_id AND (EXTRACT(month FROM d.date_changed) <> EXTRACT(month FROM spt.payment_date) AND EXTRACT(year FROM d.date_changed) = EXTRACT(year FROM spt.payment_date) OR EXTRACT(year FROM d.date_changed) <> EXTRACT(year FROM spt.payment_date))) b ON true
             LEFT JOIN ( SELECT stag_products.smhcsid,
                    stag_products.product_id,
                    stag_products.his_service_type,
                    stag_products.surgery_type,
                    stag_products.product_category,
                    stag_products.product_category_paris,
                    stag_products.product_category_new,
                    stag_products.default_code,
                    stag_products.product,
                    stag_products.list_price,
                    stag_products.group_id,
                    stag_products.kpi_point,
                    stag_products.kpi_point_num,
                    stag_products.product_id_kn,
                    stag_products.product_ctg_id,
                    stag_products.is_main_service,
                    stag_products.uom_id,
                    stag_products.uom,
                    stag_products.is_no_kpi,
                    stag_products.kdtc_product_ctg_id,
                    stag_products.create_date,
                    stag_products.write_date,
                    stag_products.is_vip,
                    stag_products.kpi_first_time
                   FROM {{ ref('stag_products') }}
                  WHERE stag_products.product_category::text <> 'SAN PHAM'::text) sp ON sp.product_id = b.product_id
             LEFT JOIN {{ source('ovs_source', 'crm_lead') }} cl ON cl.id = d.crm_id
             LEFT JOIN {{ source('ovs_source', 'm_res_company') }} mrs ON mrs.id = b.company_id
             LEFT JOIN {{ source('ovs_source', 'res_brand') }} rb ON rb.id = mrs.brand_id
        )
 SELECT p.crm_id,
    p.brand,
    p.company,
    p.booking,
    p.old_value_char,
    p.new_value_char,
    p.date_changed,
    p.product,
    p.ma_phieu,
    p.payment,
    p.payment_date,
    p.company_id,
    p.id,
    p.clineid,
    p.product_category
   FROM p
  WHERE (EXISTS ( SELECT 1
           FROM d
          WHERE d.crm_id = p.crm_id AND d.payment_date >= p.payment_date)) AND p.payment_date >= '2025-01-01'::date AND p.brand::text = 'Kangnam'::text AND p.product IS NOT NULL
  ORDER BY p.brand, p.crm_id
