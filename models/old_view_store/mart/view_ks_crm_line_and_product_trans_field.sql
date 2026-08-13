{{
  config(
    materialized = 'view',
    alias        = 'view_ks_crm_line_and_product_trans_field'
  )
}}
-- =============================================================================
-- view_ks_crm_line_and_product_trans_field
-- Backup logic từ view cũ trên sandbox (staging_sci @ 10.10.10.226) vào dbt để
-- có chỗ tra cứu lại nếu sau này bị mất/sửa nhầm ở nguồn. Sandbox là bản lưu
-- tĩnh (dbt không chạy ở đó) nên không có rủi ro DROP CASCADE, nhưng đưa vào
-- dbt/git để có version control + không phụ thuộc 1 bản duy nhất trên sandbox.
-- Logic giữ NGUYÊN VẸN so với view gốc, chỉ thay tên bảng thô bằng macro
-- source()/ref(), không sửa bất kỳ điều kiện lọc nào.
-- =============================================================================

 WITH cte_partner AS (
         SELECT ru.id,
            rp.name,
            rp.code_customer,
            ru.brand_etl
           FROM {{ source('ovs_source', 'res_users') }} ru
             LEFT JOIN {{ source('ovs_source', 'res_partner') }} rp ON rp.id = ru.partner_id AND rp.brand_etl = ru.brand_etl
        ), data_1 AS (
         SELECT kcltf.id,
            cl.name AS booking,
            kcltf.start_date + '07:00:00'::interval AS start_date,
            kcltf.expiration_date::timestamp without time zone + '07:00:00'::interval AS expiration_date,
            kcltf.status,
            kcltf.write_uid,
            cl.brand_id,
            mrc.name AS chinhanh,
            rb.name AS thuonghieu,
            kcltf.consultants_1,
            kcltf.consultants_2,
            kcltf.consultants_3,
            cp1.name AS name_consultants_1,
            cp2.name AS name_consultants_2,
            cp3.name AS name_consultants_3,
            kcltf.product_id,
            sp.product,
            kcltf.quantity,
            kcltf.brand_etl
           FROM {{ source('ovs_source', 'ks_crm_line_trans_field') }} kcltf
             LEFT JOIN {{ source('ovs_source', 'crm_lead') }} cl ON cl.id = kcltf.crm_id AND cl.brand_etl = kcltf.brand_etl
             LEFT JOIN {{ source('ovs_source', 'm_res_company') }} mrc ON mrc.id = cl.company_id AND mrc.brand_etl = cl.brand_etl
             LEFT JOIN {{ source('ovs_source', 'res_brand') }} rb ON mrc.brand_id = rb.id AND mrc.brand_etl = rb.brand_etl
             LEFT JOIN cte_partner cp1 ON cp1.id = kcltf.consultants_1 AND cp1.brand_etl = kcltf.brand_etl
             LEFT JOIN cte_partner cp2 ON cp2.id = kcltf.consultants_2 AND cp2.brand_etl = kcltf.brand_etl
             LEFT JOIN cte_partner cp3 ON cp3.id = kcltf.consultants_3 AND cp3.brand_etl = kcltf.brand_etl
             LEFT JOIN {{ ref('stag_products') }} sp ON sp.product_id = kcltf.product_id
             LEFT JOIN {{ source('ovs_source', 'crm_line') }} cl2 ON cl2.id = kcltf.id AND cl2.brand_etl = kcltf.brand_etl
          WHERE cl2.stage::text <> 'cancel'::text
        ), service_consul_1 AS (
         SELECT 'Bán dịch vụ'::text AS "table",
            'Tư vấn viên 1'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.name_consultants_1 AS old_data,
            lag(cltf.name_consultants_1, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_1 cltf
        ), service_consul_2 AS (
         SELECT 'Bán dịch vụ'::text AS "table",
            'Tư vấn viên 2'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.name_consultants_2 AS old_data,
            lag(cltf.name_consultants_2, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_1 cltf
        ), service_consul_3 AS (
         SELECT 'Bán dịch vụ'::text AS "table",
            'Tư vấn viên 3'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.name_consultants_3 AS old_data,
            lag(cltf.name_consultants_3, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_1 cltf
        ), service_product AS (
         SELECT 'Bán dịch vụ'::text AS "table",
            'Dịch vụ'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.product AS old_data,
            lag(cltf.product, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_1 cltf
        ), service_quantity AS (
         SELECT 'Bán dịch vụ'::text AS "table",
            'Số lượng'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.quantity AS old_data,
            lag(cltf.quantity, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_1 cltf
        ), data_2 AS (
         SELECT kcltf.id,
            cl.name AS booking,
            kcltf.start_date + '07:00:00'::interval AS start_date,
            kcltf.expiration_date::timestamp without time zone + '07:00:00'::interval AS expiration_date,
            kcltf.status,
            kcltf.write_uid,
            cl.brand_id,
            mrc.name AS chinhanh,
            rb.name AS thuonghieu,
            kcltf.consultants_1,
            kcltf.consultants_2,
            kcltf.consultants_3,
            cp1.name AS name_consultants_1,
            cp2.name AS name_consultants_2,
            cp3.name AS name_consultants_3,
            kcltf.product_id,
            sp.product,
            kcltf.product_uom_qty,
            kcltf.brand_etl
           FROM {{ source('ovs_source', 'ks_crm_line_product_trans_field') }} kcltf
             LEFT JOIN {{ source('ovs_source', 'crm_lead') }} cl ON cl.id = kcltf.booking_id AND cl.brand_etl = kcltf.brand_etl
             LEFT JOIN {{ source('ovs_source', 'm_res_company') }} mrc ON mrc.id = cl.company_id AND mrc.brand_etl = cl.brand_etl
             LEFT JOIN {{ source('ovs_source', 'res_brand') }} rb ON mrc.brand_id = rb.id AND mrc.brand_etl = rb.brand_etl
             LEFT JOIN cte_partner cp1 ON cp1.id = kcltf.consultants_1 AND cp1.brand_etl = kcltf.brand_etl
             LEFT JOIN cte_partner cp2 ON cp2.id = kcltf.consultants_2 AND cp2.brand_etl = kcltf.brand_etl
             LEFT JOIN cte_partner cp3 ON cp3.id = kcltf.consultants_3 AND cp3.brand_etl = kcltf.brand_etl
             LEFT JOIN {{ ref('stag_products') }} sp ON sp.product_id = kcltf.product_id
             LEFT JOIN {{ source('ovs_source', 'crm_line_product') }} clp ON clp.id = kcltf.id AND clp.brand_etl = kcltf.brand_etl
          WHERE clp.stage_line_product::text <> 'cancel'::text
        ), product_consul_1 AS (
         SELECT 'Bán sản phẩm'::text AS "table",
            'Tư vấn viên 1'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.name_consultants_1 AS old_data,
            lag(cltf.name_consultants_1, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_2 cltf
        ), product_consul_2 AS (
         SELECT 'Bán sản phẩm'::text AS "table",
            'Tư vấn viên 2'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.name_consultants_2 AS old_data,
            lag(cltf.name_consultants_2, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_2 cltf
        ), product_consul_3 AS (
         SELECT 'Bán sản phẩm'::text AS "table",
            'Tư vấn viên 3'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.name_consultants_3 AS old_data,
            lag(cltf.name_consultants_3, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_2 cltf
        ), product_product AS (
         SELECT 'Bán sản phẩm'::text AS "table",
            'Sản phẩm'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.product AS old_data,
            lag(cltf.product, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_2 cltf
        ), product_quantity AS (
         SELECT 'Bán sản phẩm'::text AS "table",
            'Số lượng'::text AS type_data,
            cltf.id,
            cltf.booking,
            cltf.chinhanh,
            cltf.product,
            cltf.product_uom_qty AS old_data,
            lag(cltf.product_uom_qty, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS new_data,
            lag(cltf.start_date, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS date_changed,
            lag(cltf.write_uid, '-1'::integer) OVER (PARTITION BY cltf.id ORDER BY cltf.start_date) AS write_uid,
            cltf.status,
            cltf.brand_etl
           FROM data_2 cltf
        )
 SELECT service_consul_1."table",
    service_consul_1.type_data,
    service_consul_1.id,
    service_consul_1.booking,
    service_consul_1.chinhanh,
    service_consul_1.product,
    service_consul_1.old_data,
    service_consul_1.new_data,
    service_consul_1.date_changed,
    service_consul_1.write_uid,
    service_consul_1.status,
    service_consul_1.brand_etl
   FROM service_consul_1
  WHERE service_consul_1.status = 'N'::text AND service_consul_1.old_data::text <> service_consul_1.new_data::text
UNION ALL
 SELECT service_consul_2."table",
    service_consul_2.type_data,
    service_consul_2.id,
    service_consul_2.booking,
    service_consul_2.chinhanh,
    service_consul_2.product,
    service_consul_2.old_data,
    service_consul_2.new_data,
    service_consul_2.date_changed,
    service_consul_2.write_uid,
    service_consul_2.status,
    service_consul_2.brand_etl
   FROM service_consul_2
  WHERE service_consul_2.status = 'N'::text AND service_consul_2.old_data::text <> service_consul_2.new_data::text
UNION ALL
 SELECT service_consul_3."table",
    service_consul_3.type_data,
    service_consul_3.id,
    service_consul_3.booking,
    service_consul_3.chinhanh,
    service_consul_3.product,
    service_consul_3.old_data,
    service_consul_3.new_data,
    service_consul_3.date_changed,
    service_consul_3.write_uid,
    service_consul_3.status,
    service_consul_3.brand_etl
   FROM service_consul_3
  WHERE service_consul_3.status = 'N'::text AND service_consul_3.old_data::text <> service_consul_3.new_data::text
UNION ALL
 SELECT service_product."table",
    service_product.type_data,
    service_product.id,
    service_product.booking,
    service_product.chinhanh,
    service_product.product,
    service_product.old_data,
    service_product.new_data,
    service_product.date_changed,
    service_product.write_uid,
    service_product.status,
    service_product.brand_etl
   FROM service_product
  WHERE service_product.status = 'N'::text AND service_product.old_data::text <> service_product.new_data::text
UNION ALL
 SELECT service_quantity."table",
    service_quantity.type_data,
    service_quantity.id,
    service_quantity.booking,
    service_quantity.chinhanh,
    service_quantity.product,
    service_quantity.old_data::text AS old_data,
    service_quantity.new_data::text AS new_data,
    service_quantity.date_changed,
    service_quantity.write_uid,
    service_quantity.status,
    service_quantity.brand_etl
   FROM service_quantity
  WHERE service_quantity.status = 'N'::text AND service_quantity.old_data::text <> service_quantity.new_data::text
UNION ALL
 SELECT product_consul_1."table",
    product_consul_1.type_data,
    product_consul_1.id,
    product_consul_1.booking,
    product_consul_1.chinhanh,
    product_consul_1.product,
    product_consul_1.old_data,
    product_consul_1.new_data,
    product_consul_1.date_changed,
    product_consul_1.write_uid,
    product_consul_1.status,
    product_consul_1.brand_etl
   FROM product_consul_1
  WHERE product_consul_1.status = 'N'::text AND product_consul_1.old_data::text <> product_consul_1.new_data::text
UNION ALL
 SELECT product_consul_2."table",
    product_consul_2.type_data,
    product_consul_2.id,
    product_consul_2.booking,
    product_consul_2.chinhanh,
    product_consul_2.product,
    product_consul_2.old_data,
    product_consul_2.new_data,
    product_consul_2.date_changed,
    product_consul_2.write_uid,
    product_consul_2.status,
    product_consul_2.brand_etl
   FROM product_consul_2
  WHERE product_consul_2.status = 'N'::text AND product_consul_2.old_data::text <> product_consul_2.new_data::text
UNION ALL
 SELECT product_consul_3."table",
    product_consul_3.type_data,
    product_consul_3.id,
    product_consul_3.booking,
    product_consul_3.chinhanh,
    product_consul_3.product,
    product_consul_3.old_data,
    product_consul_3.new_data,
    product_consul_3.date_changed,
    product_consul_3.write_uid,
    product_consul_3.status,
    product_consul_3.brand_etl
   FROM product_consul_3
  WHERE product_consul_3.status = 'N'::text AND product_consul_3.old_data::text <> product_consul_3.new_data::text
UNION ALL
 SELECT product_product."table",
    product_product.type_data,
    product_product.id,
    product_product.booking,
    product_product.chinhanh,
    product_product.product,
    product_product.old_data,
    product_product.new_data,
    product_product.date_changed,
    product_product.write_uid,
    product_product.status,
    product_product.brand_etl
   FROM product_product
  WHERE product_product.status = 'N'::text AND product_product.old_data::text <> product_product.new_data::text
UNION ALL
 SELECT product_quantity."table",
    product_quantity.type_data,
    product_quantity.id,
    product_quantity.booking,
    product_quantity.chinhanh,
    product_quantity.product,
    product_quantity.old_data::text AS old_data,
    product_quantity.new_data::text AS new_data,
    product_quantity.date_changed,
    product_quantity.write_uid,
    product_quantity.status,
    product_quantity.brand_etl
   FROM product_quantity
  WHERE product_quantity.status = 'N'::text AND product_quantity.old_data::text <> product_quantity.new_data::text
