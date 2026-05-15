{{
  config(
    materialized = 'table',
    alias        = 'report_bao_cao_sua_xoa_du_lieu_changed_so'
  )
}} 

SELECT 
  c."table",
  c.type_data,
  c.id,
  c.code,
  c.product,
  c.booking_id,
  c.old_data,
  c.new_data,
  c.date_changed,
  c.write_uid,
  c.user_changed,
  c.code_customer,
  c.so_id,
  c.invoice_date,
  c.brand_etl,
  cl2.name AS booking,
  rb.name AS thuonghieu,
  mrc.name AS chinhanh
FROM {{ ref('int_bcsxdl_ks_sale_order_line_trans_field') }} c
  LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'crm_lead') }} cl2 
    ON c.booking_id = cl2.id 
    AND cl2.brand_etl = c.brand_etl
  LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb 
    ON rb.id = cl2.brand_id 
    AND rb.brand_etl = cl2.brand_etl
  LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc 
    ON mrc.id = cl2.company_id 
    AND mrc.brand_etl = cl2.brand_etl