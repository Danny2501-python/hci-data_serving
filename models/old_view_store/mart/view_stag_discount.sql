{{
  config(
    materialized = 'view',
    alias        = 'view_stag_discount'
  )
}}
-- =============================================================================
-- view_stag_discount
-- Backup logic từ view cũ trên sandbox (staging_sci @ 10.10.10.226) vào dbt để
-- có chỗ tra cứu lại nếu sau này bị mất/sửa nhầm ở nguồn. Sandbox là bản lưu
-- tĩnh (dbt không chạy ở đó) nên không có rủi ro DROP CASCADE, nhưng đưa vào
-- dbt/git để có version control + không phụ thuộc 1 bản duy nhất trên sandbox.
-- Logic giữ NGUYÊN VẸN so với view gốc, chỉ thay tên bảng thô bằng macro
-- source()/ref(), không sửa bất kỳ điều kiện lọc nào.
-- =============================================================================

 WITH dv AS (
         SELECT cl2.id AS clineid,
            cl2.crm_id,
            cl2.stage,
            COALESCE(cl2.discount_percent * cl2.total_before_discount::double precision / 100::double precision, 0::double precision) AS discount_percent,
            COALESCE(cl2.discount_cash, 0::numeric) AS discount_cash,
            COALESCE(cl2.other_discount, 0::numeric) AS other_discount,
            COALESCE(cl2.sale_to, 0::numeric) AS sale_to,
            COALESCE(cl2.discount_cs_percent, 0::double precision) AS discount_cs_percent,
            COALESCE(cl2.discount_cs_amount, 0::double precision) AS discount_cs_amount,
            COALESCE(cl2.total_discount_review, 0::double precision) AS total_discount_review,
            COALESCE(cl2.total_before_discount, 0::numeric) AS total_before_discount,
            COALESCE(cl2.total_discount, 0::numeric) AS total_discount,
                CASE
                    WHEN cl2.total_before_discount = 0::numeric THEN 0::numeric
                    ELSE cl2.total_discount / cl2.total_before_discount * 100::numeric
                END AS "%discount",
            round(
                CASE
                    WHEN cl2.total_before_discount = 0::numeric THEN 0::double precision
                    ELSE (cl2.discount_percent * cl2.total_before_discount::double precision / 100::double precision + cl2.discount_cash::double precision + cl2.other_discount::double precision +
                    CASE
                        WHEN cl2.sale_to = 0::numeric THEN cl2.sale_to
                        WHEN cl2.sale_to <> 0::numeric THEN cl2.total_before_discount - cl2.sale_to
                        ELSE NULL::numeric
                    END::double precision) / cl2.total_before_discount::double precision * 100::double precision
                END) AS "%discount_mkt",
            COALESCE(
                CASE
                    WHEN cl2.total_before_discount = 0::numeric THEN 0::double precision
                    ELSE (cl2.discount_cs_percent * cl2.total_before_discount::double precision / 100::double precision + cl2.discount_cs_amount + cl2.total_discount_review) / cl2.total_before_discount::double precision * 100::double precision
                END, 0::double precision) AS "%discount_cs",
            COALESCE(cl2.total, 0::numeric) AS total,
            COALESCE(cl2.discount_review_id, 0) AS discount_review_id,
            spt.payment_date,
            spt.id,
            spt.ma_phieu,
            sp.smhcsid,
            sp.product_id,
            sp.product_ctg_id,
            sp.product_category,
            sp.product,
                CASE
                    WHEN spt.payment IS NULL THEN 0::numeric
                    ELSE spt.payment
                END AS payment,
            spt.payment_type,
            pk.max_date,
            spt.company_id
           FROM {{ source('ovs_source', 'crm_line') }} cl2
             LEFT JOIN {{ ref('stag_products') }} sp ON sp.product_id = cl2.product_id
             -- (2026-10-14) TẠM loại brand_etl=2 (Đông Á mới vào stag_payment_transfer) để giữ nguyên output cũ — chờ review model này.
             LEFT JOIN {{ ref('stag_payment_transfer') }} spt ON cl2.id = spt.clineid AND spt.crm_id = cl2.crm_id AND coalesce(spt.brand_etl, 0) <> 2
             LEFT JOIN ( SELECT wk.booking_id,
                    wk.state,
                    date(wk.date) AS date,
                    wk.close_walkin,
                    date(max(wk.close_walkin) OVER (PARTITION BY wk.booking_id, sp_1.product_id)) AS max_date,
                    date(wk.close_walkin) - date(max(wk.close_walkin) OVER (PARTITION BY wk.booking_id, sp_1.product_id)) AS duration,
                    wk.name,
                    sp_1.product_id,
                    sp_1.product
                   FROM {{ source('ovs_source', 'sh_medical_appointment_register_walkin') }} wk
                     LEFT JOIN {{ source('ovs_source', 'sh_walkin_service_rel') }} swsr ON swsr.walkin_id = wk.id
                     LEFT JOIN {{ ref('stag_products') }} sp_1 ON sp_1.smhcsid = swsr.service_id
                  WHERE wk.state::text = 'Completed'::text) pk ON pk.booking_id = cl2.crm_id AND pk.product_id = cl2.product_id AND pk.duration = 0 AND cl2.stage::text = 'done'::text
        ), sp AS (
         SELECT clp.id AS clineid,
            clp.booking_id AS crm_id,
            clp.stage_line_product AS stage,
            COALESCE(clp.discount_percent * clp.total_before_discount / 100::double precision, 0::double precision) AS discount_percent,
            COALESCE(clp.discount_cash, 0::double precision) AS discount_cash,
            COALESCE(clp.discount_other, 0::double precision) AS other_discount,
            COALESCE(clp.total_before_discount, 0::double precision) AS total_before_discount,
            COALESCE(clp.total_before_discount - clp.total, 0::double precision) AS total_discount,
                CASE
                    WHEN clp.total_before_discount = 0::double precision THEN 0::double precision
                    ELSE (clp.total_before_discount - clp.total) / clp.total_before_discount * 100::double precision
                END AS "%discount",
            clp.total,
            COALESCE(clp.crm_discount_review) AS discount_review_id,
            spt.payment_date,
            spt.id,
            spt.ma_phieu,
            sp.smhcsid,
            sp.product_id,
            sp.product_ctg_id,
            sp.product_category,
            sp.product,
                CASE
                    WHEN spt.payment IS NULL THEN 0::numeric
                    ELSE spt.payment
                END AS payment,
            spt.payment_type,
            date(clp.date_confirm_so) AS max_date,
            spt.company_id
           FROM {{ source('ovs_source', 'crm_line_product') }} clp
             LEFT JOIN {{ ref('stag_products') }} sp ON sp.product_id = clp.product_id
             LEFT JOIN {{ ref('stag_payment_transfer') }} spt ON clp.id = spt.clineid AND spt.crm_id = clp.booking_id AND coalesce(spt.brand_etl, 0) <> 2
        )
 SELECT dv.clineid,
    dv.crm_id,
    dv.stage,
        CASE
            WHEN dv.payment_type::text = 'inbound'::text THEN dv.total_before_discount
            WHEN dv.payment_type::text = 'outbound'::text THEN - dv.total_before_discount
            ELSE dv.total_before_discount
        END AS total_before_discount,
    dv.total_discount,
    dv."%discount",
    COALESCE(dv."%discount_mkt", 0::double precision) AS "%discount_mkt",
    COALESCE(dv."%discount_cs", 0::double precision) AS "%discount_cs",
    dv.total,
    dv.discount_percent,
    round(dv.discount_cash) AS round,
    dv.other_discount,
    dv.sale_to,
    dv.discount_cs_percent,
    dv.discount_cs_amount,
    dv.total_discount_review,
    dv.payment_date,
    dv.id,
    dv.smhcsid,
    dv.ma_phieu,
    dv.payment_type,
    dv.product_id,
    dv.product_ctg_id,
    dv.product_category,
    dv.product,
    dv.max_date,
    dv.payment,
        CASE
            WHEN dv."%discount" = 100::numeric AND dv.stage::text = 'done'::text AND dv.ma_phieu IS NULL THEN dv.max_date
            ELSE dv.payment_date
        END AS dim_date,
    dv.company_id
   FROM dv
UNION ALL
 SELECT sp.clineid,
    sp.crm_id,
    sp.stage,
        CASE
            WHEN sp.payment_type::text = 'inbound'::text THEN sp.total_before_discount
            WHEN sp.payment_type::text = 'outbound'::text THEN - sp.total_before_discount
            ELSE sp.total_before_discount
        END AS total_before_discount,
    sp.total_discount,
    sp."%discount",
    0 AS "%discount_mkt",
    0 AS "%discount_cs",
    sp.total,
    sp.discount_percent,
    round(sp.discount_cash) AS round,
    sp.other_discount,
    0 AS sale_to,
    0 AS discount_cs_percent,
    0 AS discount_cs_amount,
    0 AS total_discount_review,
    sp.payment_date,
    sp.id,
    sp.smhcsid,
    sp.ma_phieu,
    sp.payment_type,
    sp.product_id,
    sp.product_ctg_id,
    sp.product_category,
    sp.product,
    sp.max_date,
    sp.payment,
        CASE
            WHEN sp."%discount" = 100::double precision AND sp.stage::text = 'sold'::text AND sp.ma_phieu IS NULL THEN sp.max_date
            ELSE sp.payment_date
        END AS dim_date,
    sp.company_id
   FROM sp
