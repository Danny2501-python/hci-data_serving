

SELECT 
  a_1.id AS cline_id,
  a_1."table",
  a_1.type_data,
  a_1.product AS stag_product,
  a_1.brand_etl,
  a_1.booking,
  a_1.old_data,
  a_1.new_data,
  a_1.date_changed AS stag_date_changed,
  rp.name AS user_changed
FROM {{ source('bao_cao_sua_xoa_du_lieu', 'view_ks_crm_line_and_product_trans_field') }} a_1
  LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru 
    ON ru.id = a_1.write_uid 
    AND ru.brand_etl = a_1.brand_etl
  LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp 
    ON rp.id = ru.partner_id 
    AND rp.brand_etl = ru.brand_etl
    