-- =============================================================================
-- stg_frmacpr_doanh_so
-- PASS 6: Doanh số (DS) thanh toán cho Paris.
-- =============================================================================
SELECT
    ss2.org_source                                                  AS nguon,
    ss2.org_category_code                                           AS nhom_nguon,
    CASE
        WHEN ss2.org_source LIKE '%Facebook%' THEN 'FB'
        WHEN ss2.org_source LIKE '%Seo%'      THEN 'Web'
        WHEN ss2.org_source LIKE '%Display%'  THEN 'Web'
        WHEN ss2.org_source LIKE '%Hotline%'  THEN 'Web'
        ELSE 'Khác'
    END                                                             AS kenh,
    spt.payment_date::date                                          AS ngay,
    TRIM(mndap.nhom_dv_cpo)                                        AS nhom_dv,
    CASE
        WHEN cl.overseas_vietnamese = 'marketing' THEN 'Việt Kiều'
        ELSE mrc.name
    END                                                             AS chi_nhanh,
    spt.payment::text                                               AS metric,
    'DS'::text                                                      AS type_data
FROM {{ source('paris', 'stag_payment_transfer') }}     spt
LEFT JOIN {{ source('paris', 'crm_lead') }}             cl
       ON cl.id = spt.crm_id AND cl.brand_etl = spt.brand_etl
LEFT JOIN {{ source('paris', 'view_stag_products') }}   sp
       ON sp.product_id = spt.product_id AND sp.brand_etl = spt.brand_etl
LEFT JOIN {{ source('paris', 'stag_sources') }}         ss1
       ON ss1.old_id = cl.source_id
LEFT JOIN {{ source('paris', 'stag_sources') }}         ss2
       ON ss2.old_id = ss1.id_pr
LEFT JOIN {{ source('paris', 'm_nhom_dv_adnet_paris') }} mndap
       ON mndap.default_code = sp.default_code AND sp.brand_etl = 3
LEFT JOIN {{ source('paris', 'm_res_company') }}        mrc
       ON mrc.id = cl.company_id AND mrc.brand_etl = cl.brand_etl
WHERE spt.brand_etl = 3
  AND spt.payment_date >= '{{ var("start_date", "2025-08-01") }}'::date
