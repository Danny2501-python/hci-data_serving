{{
  config(
    materialized = 'view',
    alias        = 'view_crm_line_cancel_upsell'
  )
}}
-- =============================================================================
-- view_crm_line_cancel_upsell
-- Backup logic từ view cũ trên sandbox (staging_sci @ 10.10.10.226) vào dbt để
-- có chỗ tra cứu lại nếu sau này bị mất/sửa nhầm ở nguồn. Sandbox là bản lưu
-- tĩnh (dbt không chạy ở đó) nên không có rủi ro DROP CASCADE, nhưng đưa vào
-- dbt/git để có version control + không phụ thuộc 1 bản duy nhất trên sandbox.
-- Logic giữ NGUYÊN VẸN so với view gốc, chỉ thay tên bảng thô bằng macro
-- source()/ref(), không sửa bất kỳ điều kiện lọc nào.
-- =============================================================================

 SELECT clinec.crm_id,
    rlli.clid2 AS id,
    rlli.clid1 AS clineid_cancel,
    cline.id AS clineid,
    spc.product_category AS product_category_cancel,
    sp.product_category,
    spc.product AS product_cancel,
    sp.product,
    cline.stage,
    clinec.total AS total_cancel,
    clinec.gia_truoc_huy,
    cline.total,
    row_number() OVER (PARTITION BY cline.id ORDER BY clinec.id) AS rn_clineid,
    row_number() OVER (PARTITION BY clinec.id) AS rn_clineid_cancel,
        CASE
            WHEN cline.stage::text = 'done'::text THEN 1
            WHEN cline.stage::text = 'processing'::text THEN 2
            WHEN cline.total_received > 0::numeric OR cline.stage::text = 'waiting'::text THEN 3
            WHEN cline.stage::text = 'new'::text THEN 4
            ELSE 0
        END AS order_stage,
    sum(clinec.gia_truoc_huy) OVER (PARTITION BY cline.id ORDER BY clinec.id) AS total_cancel_cumsum,
    sec.employee AS employee_line_cancel,
    sec.department AS department_line_cancel,
    se.employee,
    se.department,
    clinec.reason_line_cancel,
    clinec.product_id AS product_id_cancel,
    cline.product_id,
    cline.write_date,
    clinec.consultants_1 AS consultants_1_cancel,
    clinec.consulting_role_1,
        CASE
            WHEN clinec.consultants_1 = clinec.consultants_2 THEN NULL::integer
            ELSE clinec.consultants_2
        END AS consultants_2_cancel,
    clinec.consulting_role_2
   FROM {{ source('ovs_source', 'crm_line') }} clinec
     LEFT JOIN {{ source('ovs_source', 'res_line_line_ids') }} rlli ON clinec.id = rlli.clid1
     LEFT JOIN {{ source('ovs_source', 'crm_line') }} cline ON rlli.clid2 = cline.id
     LEFT JOIN {{ ref('stag_products') }} spc ON clinec.product_id = spc.product_id
     LEFT JOIN {{ ref('stag_products') }} sp ON cline.product_id = sp.product_id
     LEFT JOIN {{ ref('view_stag_employees_user') }} sec ON clinec.consultants_1 = sec.user_id
     LEFT JOIN {{ ref('view_stag_employees_user') }} se ON cline.consultants_1 = se.user_id
  WHERE clinec.reason_line_cancel::text = 'change_service'::text AND rlli.clid1 IS NOT NULL AND (sec.department_id = ANY (ARRAY[2049, 2058, 2081, 2082, 2086, 2093, 2097, 2101, 2102, 2119, 2138, 2140, 2144, 2148, 2156, 2163, 2164, 2168, 2170, 2174, 2181, 2193, 2194, 2197, 2205, 2250, 2255, 2300, 2305, 2308, 2314, 2333, 2344, 2345, 2377, 2379, 2430, 2557, 2563, 2612])) AND (se.department_id <> ALL (ARRAY[2049, 2058, 2081, 2082, 2086, 2093, 2097, 2101, 2102, 2119, 2138, 2140, 2144, 2148, 2156, 2163, 2164, 2168, 2170, 2174, 2181, 2193, 2194, 2197, 2205, 2250, 2255, 2300, 2305, 2308, 2314, 2333, 2344, 2345, 2377, 2379, 2430, 2557, 2563, 2612]))
  ORDER BY clinec.crm_id DESC, cline.id
