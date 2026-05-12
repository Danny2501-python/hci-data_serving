SELECT 
    al_1.res_id AS id_deleted,
    al_1.name AS contents,
    replace(im.model::text, '.'::text, '_'::text) AS table_name,
        CASE
            WHEN se.name IS NULL THEN ru.name
            ELSE se.name
        END AS deleted_username,
        CASE
            WHEN se.name IS NULL THEN ru.code_customer
            WHEN se.employee_code IS NULL THEN '0'::character varying
            ELSE se.employee_code
        END AS employee_code,
        CASE
            WHEN se.department IS NULL THEN ru.department
            ELSE se.department
        END AS department,
        CASE
            WHEN se.company IS NULL THEN ru.company
            ELSE se.company
        END AS company,
        CASE
            WHEN se.brand IS NULL THEN ru.brand
            ELSE se.brand
        END AS thuonghieu,
    al_1.brand_etl
FROM {{ source('bao_cao_sua_xoa_du_lieu', 'auditlog_log') }} al_1
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'ir_model') }} im ON im.id = al_1.model_id AND al_1.brand_etl = im.brand_etl
    LEFT JOIN LATERAL ( SELECT *
        FROM {{ ref('stg_bcsxdl_hr_employee_trans_field') }} se_1
        WHERE se_1.user_id = al_1.user_id AND date(se_1.expiration_date) >= date(al_1.create_date) AND se_1.brand_etl = al_1.brand_etl
        ORDER BY se_1.expiration_date
        LIMIT 1) se ON true
    LEFT JOIN {{ ref('stg_bcsxdl_res_user_tns') }} ru ON ru.id = al_1.user_id AND ru.brand_etl = al_1.brand_etl
WHERE al_1.method::text = 'unlink'::text