{{
  config(
    materialized = 'table',
    alias        = 'report_bao_cao_sua_xoa_du_lieu_changed_creator'
  )
}} 
SELECT DISTINCT 'erp'::text AS "table",
    'create_uid <> create_by'::text AS type_data,
    cl.id,
    cl.name,
    cl.type,
    cl.create_uid,
    rp.name AS old_data,
    cl.create_date + '07:00:00'::interval AS "create_date in message",
    cl.create_by,
    rp1.name AS new_data,
    cl.create_on + '07:00:00'::interval AS "create_date in footer",
    cl.user_id,
    rp2.name AS "Nhân viên kinh doanh",
    cl.brand_id,
    rb.name AS thuonghieu,
    mrc.name AS chinhanh,
    cl.source_id,
        CASE
            WHEN cl.brand_id = 3 THEN ss2.org_source
            ELSE ss1.source
        END AS source,
        CASE
            WHEN cl.brand_id = 3 THEN ss2.category_source_code
            ELSE ss1.category_source_code
        END AS category_source_code,
    cl.create_date + '07:00:00'::interval AS date_changed,
    rp1.name AS user_changed
   FROM {{ source('bao_cao_sua_xoa_du_lieu', 'crm_lead') }} cl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb ON rb.id = cl.brand_id AND rb.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc ON mrc.id = cl.company_id AND mrc.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru ON ru.id = cl.create_uid AND ru.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp ON rp.id = ru.partner_id AND rp.brand_etl = ru.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru1 ON ru1.id = cl.create_by AND ru1.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp1 ON rp1.id = ru1.partner_id AND rp1.brand_etl = ru1.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru2 ON ru2.id = cl.user_id AND ru2.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp2 ON rp2.id = ru2.partner_id AND rp2.brand_etl = ru2.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'stag_sources') }} ss1 ON ss1.old_id = cl.source_id::double precision
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'stag_sources') }} ss2 ON ss2.old_id = ss1.id_pr::double precision
  WHERE cl.create_uid <> cl.create_by AND cl.active IS TRUE
UNION ALL
 SELECT 'log'::text AS "table",
    a.type_data,
    a.id,
    a.booking AS name,
    cl.type,
    cl.create_uid,
    a.old_data,
    cl.create_date + '07:00:00'::interval AS "create_date in message",
    cl.create_by,
    a.new_data,
    cl.create_on + '07:00:00'::interval AS "create_date in footer",
    cl.user_id,
    rp2.name AS "Nhân viên kinh doanh",
    cl.brand_id,
    rb.name AS thuonghieu,
    mrc.name AS chinhanh,
    cl.source_id,
        CASE
            WHEN cl.brand_id = 3 THEN ss2.org_source
            ELSE ss1.source
        END AS source,
        CASE
            WHEN cl.brand_id = 3 THEN ss2.category_source_code
            ELSE ss1.category_source_code
        END AS category_source_code,
    a.date_changed,
    rp3.name AS user_changed
   FROM {{ source('bao_cao_sua_xoa_du_lieu', 'view_ks_crm_lead_trans_field') }} a
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'crm_lead') }} cl ON cl.id = a.id AND cl.brand_etl = a.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb ON rb.id = cl.brand_id AND rb.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc ON mrc.id = cl.company_id AND mrc.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru3 ON ru3.id = a.write_uid AND ru3.brand_etl = a.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp3 ON rp3.id = ru3.partner_id AND rp3.brand_etl = ru3.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru ON ru.id = cl.create_uid AND ru.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp ON rp.id = ru.partner_id AND rp.brand_etl = ru.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru1 ON ru1.id = cl.create_by AND ru1.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp1 ON rp1.id = ru1.partner_id AND rp1.brand_etl = ru1.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru2 ON ru2.id = cl.user_id AND ru2.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp2 ON rp2.id = ru2.partner_id AND rp2.brand_etl = ru2.brand_etl
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'stag_sources') }} ss1 ON ss1.old_id = cl.source_id::double precision
     LEFT JOIN {{ source('bao_cao_sua_xoa_du_lieu', 'stag_sources') }} ss2 ON ss2.old_id = ss1.id_pr::double precision
  WHERE a.type_data <> 'source'::text