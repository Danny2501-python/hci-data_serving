
SELECT 
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
    a_1.status_bk,
    a_1.brand_etl
FROM {{ source('bao_cao_sua_xoa_du_lieu', 'stag_mail_message_erp') }} a_1
WHERE a_1.type_data = 'changed_consultant'::text

-- lấy các log sửa người tư vấn của booking