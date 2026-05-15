{{
  config(
    materialized = 'table',
    alias        = 'report_bao_cao_sua_xoa_du_lieu_hospital'
  )
}}

WITH a AS (
         SELECT *
           FROM {{ ref('stg_bcsxdl_view_ks_sh_medical_surgery') }}
          WHERE type_data = 'Thành viên'::text
    ), b AS (
        SELECT *
        FROM {{ ref('stg_bcsxdl_view_ks_sh_medical_surgery') }}
        WHERE type_data = 'Vai trò'::text
    ), c AS (
        SELECT *
        FROM {{ ref('stg_bcsxdl_view_ks_sh_medical_surgery') }}
        WHERE type_data <> 'Thành viên'::text
    ), a1 AS (
        SELECT 'medical_surgery'::text AS type_specialty,
        a."table",
        a.type_data,
        a.id,
        a.ma_phieu,
        a.medical_id,
        a.notes,
        a.old_data,
        a.new_data,
        a.date_changed,
        a.write_uid,
        a.status,
        a.brand_etl,
        rp.name AS user_changed,
        rp.code_customer,
        cl2.name AS booking,
        rb.name AS thuong_hieu,
        mrc.name AS chi_nhanh,
            CASE
                WHEN b.new_data IS NOT NULL THEN ''::character varying
                ELSE smtr.name
            END AS role
        FROM a
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_users')}} ru ON ru.id = a.write_uid AND ru.brand_etl = a.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_partner')}} rp ON rp.id = ru.partner_id AND rp.brand_etl = ru.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_surgery')}} sms ON sms.id = a.medical_id AND sms.brand_etl = a.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'crm_lead')}} cl2 ON cl2.id = sms.booking_id AND cl2.brand_etl = sms.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_brand')}} rb ON rb.id = cl2.brand_id AND rb.brand_etl = cl2.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'm_res_company')}} mrc ON mrc.id = cl2.company_id AND mrc.brand_etl = cl2.brand_etl
            LEFT JOIN b ON b.id = a.id AND a.brand_etl = b.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_surgery_team')}} smst ON smst.id = a.id AND smst.brand_etl = a.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_team_role')}} smtr ON smtr.id = smst.role AND smtr.brand_etl = smst.brand_etl
    UNION ALL
        SELECT 'medical_surgery'::text AS type_specialty,
        c."table",
        c.type_data,
        c.id,
        c.ma_phieu,
        c.medical_id,
        c.notes,
        c.old_data,
        c.new_data,
        c.date_changed,
        c.write_uid,
        c.status,
        c.brand_etl,
        rp.name AS user_changed,
        rp.code_customer,
        cl2.name AS booking,
        rb.name AS thuong_hieu,
        mrc.name AS chi_nhanh,
        ''::character varying AS role
        FROM c
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_users')}} ru ON ru.id = c.write_uid AND ru.brand_etl = c.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_partner')}} rp ON rp.id = ru.partner_id AND rp.brand_etl = ru.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_surgery')}} sms ON sms.id = c.medical_id AND sms.brand_etl = c.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'crm_lead')}} cl2 ON cl2.id = sms.booking_id AND cl2.brand_etl = sms.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_brand')}} rb ON rb.id = cl2.brand_id AND rb.brand_etl = cl2.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'm_res_company')}} mrc ON mrc.id = cl2.company_id AND mrc.brand_etl = cl2.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_surgery_team')}} smst ON smst.id = c.id AND smst.brand_etl = c.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_team_role')}} smtr ON smtr.id = smst.role AND smtr.brand_etl = smst.brand_etl
    UNION ALL
        SELECT 'medical_specialty'::text AS type_specialty,
        a."table",
        a.type_data,
        a.id,
        a.ma_phieu,
        a.medical_id,
        a.notes,
        a.old_data,
        a.new_data,
        a.date_changed,
        a.write_uid,
        a.status,
        a.brand_etl,
        rp.name AS user_changed,
        rp.code_customer,
        cl2.name AS booking,
        rb.name AS thuong_hieu,
        mrc.name AS chi_nhanh,
            CASE
                WHEN b.new_data IS NOT NULL THEN ''::character varying
                ELSE smtr.name
            END AS role
        FROM a
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_users')}} ru ON ru.id = a.write_uid AND ru.brand_etl = a.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_partner')}} rp ON rp.id = ru.partner_id AND rp.brand_etl = ru.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_specialty')}} sms ON sms.id = a.medical_id AND sms.brand_etl = a.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'crm_lead')}} cl2 ON cl2.id = sms.booking_id AND cl2.brand_etl = sms.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_brand')}} rb ON rb.id = cl2.brand_id AND rb.brand_etl = cl2.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'm_res_company')}} mrc ON mrc.id = cl2.company_id AND mrc.brand_etl = cl2.brand_etl
            LEFT JOIN b ON b.id = a.id AND b.brand_etl = a.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_specialty_team')}} smst ON smst.id = a.id AND smst.brand_etl = a.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_team_role')}} smtr ON smtr.id = smst.role AND smtr.brand_etl = smst.brand_etl
    UNION ALL
        SELECT 'medical_specialty'::text AS type_specialty,
        c."table",
        c.type_data,
        c.id,
        c.ma_phieu,
        c.medical_id,
        c.notes,
        c.old_data,
        c.new_data,
        c.date_changed,
        c.write_uid,
        c.status,
        c.brand_etl,
        rp.name AS user_changed,
        rp.code_customer,
        cl2.name AS booking,
        rb.name AS thuong_hieu,
        mrc.name AS chi_nhanh,
        ''::character varying AS role
        FROM c
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_users')}} ru ON ru.id = c.write_uid AND ru.brand_etl = c.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_partner')}} rp ON rp.id = ru.partner_id AND rp.brand_etl = ru.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_specialty')}} sms ON sms.id = c.medical_id AND sms.brand_etl = c.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'crm_lead')}} cl2 ON cl2.id = sms.booking_id AND cl2.brand_etl = sms.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'res_brand')}} rb ON rb.id = cl2.brand_id AND rb.brand_etl = cl2.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'm_res_company')}} mrc ON mrc.id = cl2.company_id AND mrc.brand_etl = cl2.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_specialty_team')}} smst ON smst.id = c.id AND smst.brand_etl = c.brand_etl
            LEFT JOIN {{source('bao_cao_sua_xoa_du_lieu', 'sh_medical_team_role')}} smtr ON smtr.id = smst.role AND smtr.brand_etl = smst.brand_etl
    )
 SELECT a1.type_specialty,
    a1."table",
    a1.type_data,
    a1.id,
    a1.ma_phieu,
    a1.medical_id,
    a1.notes,
    a1.old_data,
    a1.new_data,
    a1.date_changed,
    a1.write_uid,
    a1.status,
    a1.brand_etl,
    a1.user_changed,
    a1.code_customer,
    a1.booking,
    a1.thuong_hieu,
    a1.chi_nhanh,
    a1.role
FROM a1