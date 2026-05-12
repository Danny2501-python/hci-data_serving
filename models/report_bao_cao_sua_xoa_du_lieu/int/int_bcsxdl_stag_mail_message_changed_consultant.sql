

SELECT 
    dt.id,
    dt.field_desc,
    CASE
        WHEN se1.department IS NULL THEN '0'::character varying
        ELSE se1.department
    END AS department_old,
    se1.company AS company_old,
    dt.old_value_char,
    CASE
        WHEN se2.department IS NULL THEN '0'::character varying
        ELSE se2.department
    END AS department_new,
    se2.company AS company_new,
    dt.new_value_char,
    dt.date_changed,
    dt.res_id,
    dt.write_uid,
    cl2_1.name,
    CASE
        WHEN ru.name IS NULL THEN ss.name
        ELSE ru.name
    END AS nguoi_sua,
    CASE
        WHEN ru.name IS NULL THEN ss.code_customer
        WHEN ru.employee_code IS NULL THEN '0'::character varying
        ELSE ru.employee_code
    END AS employee_code,
    ru.work_email AS email,
    CASE
        WHEN ru.department IS NULL THEN ss.department
        ELSE ru.department
    END AS department,
    vsp.product AS line_dichvu,
    cl_1.create_date + '07:00:00'::interval AS create_date_line,
    cl_1.stage,
    rb_1.name AS thuong_hieu_1,
    mrc_1.name AS chi_nhanh_1,
    dt.booking_won_date,
    dt.status_bk,
    dt.brand_etl
FROM {{ ref('stg_bcsxdl_stag_mail_message_changed_consultant') }} dt
    LEFT JOIN LATERAL ( 
        SELECT *
        FROM {{ ref('stg_bcsxdl_hr_employee_trans_field') }} ru_1
        WHERE dt.write_uid = ru_1.user_id 
            AND date(ru_1.expiration_date) >= date(dt.write_date) 
            AND dt.brand_etl = ru_1.brand_etl
        ORDER BY ru_1.expiration_date
        LIMIT 1) ru ON true
    LEFT JOIN {{ ref('stg_bcsxdl_res_user_tns') }} ss ON ss.id = dt.write_uid AND ss.brand_etl = dt.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'crm_line') }} cl_1 ON cl_1.id = dt.res_id AND cl_1.brand_etl = dt.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'crm_lead') }} cl2_1 ON cl2_1.id = cl_1.crm_id AND cl2_1.brand_etl = cl_1.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'view_stag_products') }} vsp ON vsp.product_id = cl_1.product_id AND vsp.brand_etl = cl_1.brand_etl
    LEFT JOIN LATERAL ( 
        SELECT *
        FROM {{ ref('stg_bcsxdl_hr_employee_trans_field') }} se1_1
        WHERE se1_1.user_id = dt.old_value_integer 
            AND date(se1_1.expiration_date) >= date(dt.write_date) 
            AND se1_1.brand_etl = dt.brand_etl
        ORDER BY se1_1.expiration_date
        LIMIT 1) se1 ON true
    LEFT JOIN LATERAL ( 
        SELECT *
        FROM {{ ref('stg_bcsxdl_hr_employee_trans_field') }} se2_1
        WHERE se2_1.user_id = dt.new_value_integer 
            AND date(se2_1.expiration_date) >= date(dt.write_date) 
            AND se2_1.brand_etl = dt.brand_etl
        ORDER BY se2_1.expiration_date
        LIMIT 1) se2 ON true
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb_1 ON rb_1.id = cl2_1.brand_id AND rb_1.brand_etl = cl2_1.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc_1 ON mrc_1.id = cl2_1.company_id AND mrc_1.brand_etl = cl2_1.brand_etl