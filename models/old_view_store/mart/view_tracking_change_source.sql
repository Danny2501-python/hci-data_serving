{{
  config(
    materialized = 'view',
    alias        = 'view_tracking_change_source'
  )
}}
-- =============================================================================
-- view_tracking_change_source
-- Backup logic từ view cũ trên sandbox (staging_sci @ 10.10.10.226) vào dbt để
-- có chỗ tra cứu lại nếu sau này bị mất/sửa nhầm ở nguồn. Sandbox là bản lưu
-- tĩnh (dbt không chạy ở đó) nên không có rủi ro DROP CASCADE, nhưng đưa vào
-- dbt/git để có version control + không phụ thuộc 1 bản duy nhất trên sandbox.
-- Logic giữ NGUYÊN VẸN so với view gốc, chỉ thay tên bảng thô bằng macro
-- source()/ref(), không sửa bất kỳ điều kiện lọc nào.
-- =============================================================================

 WITH data_mail_message AS (
         SELECT b_1.id,
            b_1.res_id,
            b_1.write_uid,
            b_1.write_date + '07:00:00'::interval AS write_date
           FROM {{ source('ovs_source', 'mail_message') }} b_1
          WHERE b_1.model = 'crm.lead'::text AND b_1.create_date >= '2023-01-01 00:00:00'::timestamp without time zone
        ), data_tracking AS (
         SELECT s.id,
            s.field,
            s.field_desc,
            s.field_type,
            s.old_value_integer,
            s.old_value_char,
            s.new_value_integer,
            s.new_value_char,
            s.mail_message_id,
            s.create_uid,
            s.create_date + '07:00:00'::interval AS create_date,
            s.write_uid,
            s.write_date + '07:00:00'::interval AS write_date
           FROM {{ source('ovs_source', 'mail_tracking_value') }} s
          WHERE date(s.create_date) >= '2023-01-01'::date AND s.field = 'source_id'::text AND (EXISTS ( SELECT 1
                   FROM data_mail_message b_1
                  WHERE b_1.id = s.mail_message_id))
        )
 SELECT b.res_id AS crm_id,
    b.create_date AS change_source_date,
    a.old_value_integer AS source_before_change_id,
    a.new_value_integer AS change_source_new_id,
    a.old_value_char AS source_before_change_org,
    a.new_value_char AS change_source_new_org,
    sso.source AS source_before_change,
    ss.source AS change_source_new,
    se.user_id,
    initcap(se.employee::text) AS change_source_employee,
    se.job AS change_source_job
   FROM data_tracking a
     LEFT JOIN {{ source('ovs_source', 'mail_message') }} b ON b.id = a.mail_message_id
     LEFT JOIN {{ ref('view_stag_employees_user') }} se ON b.create_uid = se.user_id
     LEFT JOIN {{ source('ovs_source', 'stag_sources') }} sso ON a.old_value_integer::double precision = sso.old_id
     LEFT JOIN {{ source('ovs_source', 'stag_sources') }} ss ON a.new_value_integer::double precision = ss.old_id
