{{
  config(
    materialized = 'ephemeral'
  )
}}

-- Chỉ tính brand_etl = 1 (thương hiệu Kangnam).
--
-- Nhóm dịch vụ chính của booking (crm_id), lấy theo thứ tự ưu tiên:
--   1. crm_lead_product_category_rel -> product_category.name
--      (1 lead_id có thể có nhiều category -> lấy category xuất hiện đầu tiên theo
--      ingestion_timestamp; các cặp thường gặp đều cùng business line PTTM nên không
--      cần phân biệt sâu hơn)
--   2. custom_fields id=9794 ("Nhóm dịch vụ chính") trên cs_deal_detail_api_v2 (nối qua
--      crm_lead.ticket_id = cs_deal_detail_api_v2.id) -> value (thực chất là value_id) join
--      cs_custom_fields.value_id (kèm custom_field_id='9794') để lấy value_lable, bóc bỏ
--      phần mã trong ngoặc vuông (vd "[KNP00001] PTTM MẮT" -> "PTTM MẮT")
--   3. Nếu cả 2 ưu tiên trên đều không có: product_category của dòng dịch vụ (cline) đầu
--      tiên trong booking, theo create_date
--
-- business_line: map nhom_dich_vu_chinh -> his_service_type (view_stag_products) -> business_line
-- theo cùng quy tắc business_line đang dùng ở stg_booking_xet_ban_cheo.sql. 1 product_category có
-- thể gắn với nhiều his_service_type (vd "PTTM KHÁC" có cả ChiPhi/Laser/Surgery/wellness) nên lấy
-- his_service_type xuất hiện nhiều nhất (mode) cho category đó. Category nào không khớp được với
-- product_category trong view_stag_products (khác biệt cách đặt tên giữa các nguồn) thì business_line
-- trả về NULL thay vì ép về 'Khác', để phân biệt với trường hợp có his_service_type nhưng không thuộc
-- 5 nhóm liệt kê.

WITH cat_business_line_map AS (
    SELECT
        product_category,
        CASE
            WHEN his_service_type = 'Surgery' then 'PTTM'
            WHEN his_service_type IN ('Spa','Laser','Card') then 'Beauty & Spa'
            WHEN his_service_type = 'Odontology' then 'Nha khoa'
            WHEN his_service_type = 'wellness' then 'Wellness'
            WHEN his_service_type = 'weight_loss' then 'Weight Loss'
            ELSE 'Khác'
        END as business_line
    FROM (
        SELECT
            product_category,
            his_service_type,
            ROW_NUMBER() OVER (
                PARTITION BY product_category
                ORDER BY COUNT(*) DESC
            ) as rn
        FROM {{ source('crm_base', 'view_stag_products') }}
        WHERE product_category IS NOT NULL
            AND brand_etl = 1
        GROUP BY product_category, his_service_type
    ) t
    WHERE rn = 1

), uu_tien_1 AS (
    SELECT
        rel.crm_id,
        rel.brand_etl,
        rel.nhom_dich_vu_chinh,
        1 as do_uu_tien
    FROM (
        SELECT
            r.lead_id as crm_id,
            r.brand_etl,
            pc.name as nhom_dich_vu_chinh,
            ROW_NUMBER() OVER (
                PARTITION BY r.lead_id, r.brand_etl
                ORDER BY r.ingestion_timestamp ASC
            ) as rn
        FROM {{ source('crm_base', 'crm_lead_product_category_rel') }} r
            LEFT JOIN {{ source('crm_base', 'product_category') }} pc
                ON pc.id = r.product_category_id AND pc.brand_etl = r.brand_etl
        WHERE r.product_category_id IS NOT NULL
            AND r.brand_etl = 1
    ) rel
    WHERE rel.rn = 1

), uu_tien_2 AS (
    SELECT
        cl.id as crm_id,
        cl.brand_etl,
        CASE
            WHEN ccf.value_lable LIKE '%]%' THEN TRIM(SPLIT_PART(ccf.value_lable, ']', 2))
            ELSE TRIM(ccf.value_lable)
        END as nhom_dich_vu_chinh,
        2 as do_uu_tien
    FROM {{ source('crm_base', 'crm_lead') }} cl
        INNER JOIN {{ source('crm_base', 'cs_deal_detail_api_v2') }} cda ON cda.id = cl.ticket_id
        CROSS JOIN LATERAL jsonb_array_elements(cda.custom_fields::jsonb) cf_elem
        LEFT JOIN {{ source('crm_base', 'cs_custom_fields') }} ccf
            ON ccf.value_id = (cf_elem ->> 'value')
            AND ccf.custom_field_id = '9794'
    WHERE cf_elem ->> 'id' = '9794'
        AND ccf.value_lable IS NOT NULL
        AND cl.brand_etl = 1

), uu_tien_3 AS (
    SELECT
        line.crm_id,
        line.brand_etl,
        line.nhom_dich_vu_chinh,
        3 as do_uu_tien
    FROM (
        SELECT
            cln.crm_id,
            cln.brand_etl,
            sp.product_category as nhom_dich_vu_chinh,
            ROW_NUMBER() OVER (
                PARTITION BY cln.crm_id, cln.brand_etl
                ORDER BY cln.create_date
            ) as rn
        FROM {{ source('crm_base', 'crm_line') }} cln
            LEFT JOIN {{ source('crm_base', 'view_stag_products') }} sp
                ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
        WHERE cln.brand_etl = 1
    ) line
    WHERE line.rn = 1
        AND line.nhom_dich_vu_chinh IS NOT NULL

), combined AS (
    SELECT * FROM uu_tien_1
    UNION ALL
    SELECT * FROM uu_tien_2
    UNION ALL
    SELECT * FROM uu_tien_3

), ranked AS (
    SELECT
        c.*,
        ROW_NUMBER() OVER (
            PARTITION BY c.crm_id, c.brand_etl
            ORDER BY c.do_uu_tien
        ) as rn
    FROM combined c
    WHERE c.nhom_dich_vu_chinh IS NOT NULL
)
SELECT
    r.crm_id,
    r.brand_etl,
    r.nhom_dich_vu_chinh,
    r.do_uu_tien as nguon_uu_tien,
    cbl.business_line
FROM ranked r
    LEFT JOIN cat_business_line_map cbl
        ON UPPER(TRIM(cbl.product_category)) = UPPER(TRIM(r.nhom_dich_vu_chinh))
WHERE r.rn = 1
