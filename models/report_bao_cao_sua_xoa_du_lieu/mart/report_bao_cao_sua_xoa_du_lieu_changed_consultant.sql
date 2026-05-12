{{
  config(
    materialized = 'table',
    alias        = 'report_bao_cao_sua_xoa_du_lieu_changed_consultant'
  )
}} 

SELECT a.id,
    a.field_desc,
    a.department_old,
    a.company_old,
    a.old_value_char,
    a.department_new,
    a.company_new,
    a.new_value_char,
    a.date_changed,
    a.res_id,
    a.write_uid,
    a.name,
    a.nguoi_sua,
    a.employee_code,
    a.email,
    a.department,
    a.line_dichvu,
    a.create_date_line,
    a.stage,
    a.thuong_hieu_1,
    a.chi_nhanh_1,
    a.booking_won_date,
    a.status_bk,
    a.brand_etl,
    c.payment_date,
    d.payment_date AS payment_date_2,
    b.cline_id,
    b."table",
    b.type_data,
    b.stag_product,
    b.booking,
    b.old_data,
    b.new_data,
    b.stag_date_changed,
    b.user_changed,
    CASE
        WHEN a.res_id IS NULL THEN rb.name
        ELSE a.thuong_hieu_1
    END AS thuong_hieu,
    CASE
        WHEN a.res_id IS NULL THEN mrc.name
        ELSE a.chi_nhanh_1
    END AS chi_nhanh
FROM {{ ref('int_bcsxdl_stag_mail_message_changed_consultant') }} a
    FULL JOIN {{ ref('int_bcsxdl_ks_crm_line_and_product_trans_field') }} b 
        ON b.cline_id = a.res_id 
        AND a.brand_etl = b.brand_etl
    LEFT JOIN ( 
        SELECT *
        FROM {{ ref('stg_bcsxdl_stag_payment_transfer_tns') }}
        WHERE rnk = 1
    ) c ON c.clineid = a.res_id AND c.brand_etl = a.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'crm_line') }} cl 
        ON cl.id = b.cline_id AND b."table" = 'Bán dịch vụ'
        AND cl.brand_etl = b.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'crm_line_product') }} clp 
        ON clp.id = b.cline_id AND b."table" = 'Bán sản phẩm'
        AND clp.brand_etl = b.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'crm_lead') }} cl2 
        ON (cl2.id = cl.crm_id AND cl2.brand_etl = cl.brand_etl) 
        OR (cl2.id = clp.booking_id AND cl2.brand_etl = clp.brand_etl)
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb 
        ON rb.id = cl2.brand_id 
        AND rb.brand_etl = cl2.brand_etl
    LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc 
        ON mrc.id = cl2.company_id 
        AND mrc.brand_etl = cl2.brand_etl
    LEFT JOIN {{ ref('stg_bcsxdl_stag_payment_transfer_tns') }} d 
        ON d.clineid = b.cline_id 
        AND d.crm_id = cl2.id 
        AND d.brand_etl = cl2.brand_etl