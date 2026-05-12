{{
  config(
    materialized = 'table',
    alias        = 'report_bao_cao_sua_xoa_du_lieu_deleted_data'
  )
}}

SELECT 
    al.id_deleted,
    al.contents,
    al.table_name,
    al.deleted_username,
    al.employee_code,
    al.department,
    al.company,
    al.thuonghieu,
    al.brand_etl,
    ldp.write_date + '07:00:00'::interval AS deleted_date,
    ldp.raw_data,
    (ldp.raw_data::json ->> 'create_date'::text)::timestamp without time zone AS create_date
FROM {{ source('bao_cao_sua_xoa_du_lieu', 'logging_delete') }} ldp
    LEFT JOIN {{ ref('stg_bcsxdl_auditlog_log_for_deleted_data') }} al 
        ON al.id_deleted::numeric = ldp.res_id 
        AND al.table_name = ldp.table_name::text 
        AND ldp.brand_etl = al.brand_etl