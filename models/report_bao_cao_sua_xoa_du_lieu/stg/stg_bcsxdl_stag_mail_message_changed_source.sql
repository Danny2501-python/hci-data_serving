
SELECT 
    a_1.*
FROM {{ source('bao_cao_sua_xoa_du_lieu', 'stag_mail_message_erp') }} a_1
WHERE a_1.type_data = 'changed_source'::text

-- lấy các log sửa nguồn của booking