-- Pass 2: Form từ Odoo Seeding
SELECT
    rb.brand_etl || '-form-' || sf.id                               AS ids,
    TRIM(REPLACE(sf.phone, ' ', ''))                                AS phone,
    sf.code_form                                                     AS tên,
    sf.create_date + INTERVAL '7 hours'                             AS ngày,
    NULL::TEXT                                                       AS phieu_thanh_toan,
    'Form'                                                           AS bảng,
    sf.ticket_id::TEXT                                               AS ticket_id,
    sf.name                                                          AS ten_kh,
    su.name                                                          AS nhân_viên,
    rb.name                                                          AS thương_hiệu,
    mrc.name                                                         AS chi_nhánh,
    rb.id                                                            AS thuonghieuphanquyen,
    TRIM(UPPER(REGEXP_REPLACE(sf.service, '\s+', ' ', 'g')))        AS dịch_vụ,
    NULL::TEXT                                                       AS nhóm_dịch_vụ,
    NULL::INT                                                        AS prepayment_amount,
    NULL::TEXT                                                       AS payment_type,
    'Seeding (Form)'                                                 AS source,
    sf.page_name,
    sf.page_link,
    sf.doctor,
    NULL::INT                                                        AS brand_etl,
    NULL::TEXT                                                       AS create_by,
    NULL::TEXT                                                       AS create_by_department
FROM {{ ref('stg_frots_seeding_form') }} sf
LEFT JOIN {{ source('frots', 'seeding_user') }} su         ON su.id = sf.user_id
LEFT JOIN {{ source('frots', 'seeding_res_company') }} src ON sf.company_id = src.id
LEFT JOIN {{ source('frots', 'm_res_company') }} mrc       ON mrc.company_code = src.code AND mrc.brand_etl = 7
LEFT JOIN {{ source('frots', 'res_brand') }} rb            ON rb.id = mrc.brand_id AND rb.brand_etl = 7
WHERE rb.id NOT IN (2, 5, 4)
