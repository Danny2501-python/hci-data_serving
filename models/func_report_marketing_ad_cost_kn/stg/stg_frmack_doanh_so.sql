-- =============================================================================
-- stg_frmack_doanh_so  (Pass 8)
-- Revenue data with chi_nhanh remap and local_k same formula as CRM.
-- =============================================================================
WITH a AS (
    SELECT
        CASE 
              WHEN cl3.overseas_vietnamese = 'expat' THEN 'exp' 
              ELSE cl3.overseas_vietnamese 
        END                                            AS vk,
        sp.product                                     AS ten_dv,
        ss.source                                      AS nguon,
        ss.category_source                             AS nhom_nguon,
        CASE WHEN ss.source ~~ '%Facebook%' THEN 'FB'
             WHEN ss.source ~~ '%Seo%'      THEN 'Web'
             WHEN ss.source ~~ '%Google%'   THEN 'Web'
             WHEN ss.source ~~ '%Hotline%'  THEN 'Web'
             ELSE 'Khác'
        END                                            AS kenh,
        std.payment_date                               AS ngay,
        mrc.name                                       AS chi_nhanh_raw,
        std.payment                                    AS doanh_so,
        sp.product_category                            AS nhom_dv,
        CASE WHEN rcs.name = 'Thành phố Hồ Chí Minh' THEN 'SÀI GÒN'
             WHEN rcs.name = 'Thành phố Hà Nội'       THEN 'Hà Nội'
             WHEN rcs.name IS NULL                      THEN 'KXĐ'
             WHEN rcs.code NOT LIKE '%VN-%'             THEN 'VIỆT KIỀU'
             ELSE rcs.name
        END                                            AS local_k,
        rc.name                                        AS quoc_gia,
        cl3.ticket_id,
        dkq.first_product_group                        AS nhom_dv_KH_quan_tam,
        CASE
            WHEN sbn.nhom_dich_vu_chinh IS NULL THEN NULL
            WHEN sbn.nhom_dich_vu_chinh = 'BEAUTY & SPA' THEN '8.BEAUTY & SPA'
            WHEN sbn.nhom_dich_vu_chinh = 'PTTM HÀM MẶT' THEN '3.HÀM MẶT/NHA KHOA'
            WHEN sbn.nhom_dich_vu_chinh = 'WELLNESS' THEN '9.WELLNESS'
            WHEN sbn.nhom_dich_vu_chinh = 'BÉO ĐA CHUYÊN KHOA' THEN '7.BÉO ĐA CHUYÊN KHOA'
            WHEN sbn.nhom_dich_vu_chinh = 'PTTM MẮT' THEN '1.MẮT'
            WHEN sbn.nhom_dich_vu_chinh = 'PTTM MŨI' THEN '2.MŨI'
            WHEN sbn.nhom_dich_vu_chinh = 'CẤY MỠ' THEN '5.CẤY MỠ'
            WHEN sbn.nhom_dich_vu_chinh = 'PTTM NGỰC/MÔNG' THEN '4.NGỰC/MÔNG'
            ELSE '6.DỊCH VỤ KHÁC'
        END                                              AS nhom_dv_chinh_booking,
        COALESCE(us.name, monm.new_source_name)         AS nguon_moi_v2,
        cat.name                                        AS nhom_nguon_moi_v2
    FROM {{ source('kangnam', 'stag_payment_transfer') }} std
    LEFT JOIN {{ source('kangnam', 'crm_lead') }} cl3
           ON std.crm_id = cl3.id AND std.brand_etl = cl3.brand_etl
    LEFT JOIN {{ source('kangnam', 'res_country_state') }} rcs
           ON rcs.id = cl3.state_id  AND rcs.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'res_country') }} rc
           ON rc.id  = cl3.country_id AND rc.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'view_stag_products') }} sp
           ON sp.product_id = std.product_id AND sp.brand_etl = std.brand_etl
    LEFT JOIN {{ source('kangnam', 'stag_sources') }} ss
           ON ss.old_id = cl3.source_id::double precision
    LEFT JOIN {{ source('kangnam', 'm_res_company') }} mrc
           ON mrc.id = std.company_id AND mrc.brand_etl = 1
    LEFT JOIN {{ ref('stg_dv_khach_hang_quan_tam') }} dkq
           ON dkq.crm_id = cl3.id AND dkq.brand_etl = cl3.brand_etl
    LEFT JOIN {{ ref('stg_booking_nhom_dich_vu_chinh') }} sbn
           ON sbn.crm_id = cl3.id AND sbn.brand_etl = cl3.brand_etl
    LEFT JOIN {{ source('kangnam', 'utm_source') }} us
           ON us.id = cl3.new_source_id AND us.brand_id = cl3.brand_etl
    -- Fallback khi crm_lead.new_source_id NULL — xem stg_frmack_crm_base.sql
    -- cho giải thích đầy đủ về gotcha fan-out và bảng mapping dùng chung.
    LEFT JOIN LATERAL (
        SELECT new_source_name, new_source_category_id
        FROM {{ ref('m_utm_source_old_new_map') }} m
        WHERE m.old_source_id = cl3.source_id AND m.brand_etl = cl3.brand_etl
          AND cl3.new_source_id IS NULL
        ORDER BY m.new_source_id
        LIMIT 1
    ) monm ON TRUE
    LEFT JOIN {{ source('kangnam', 'crm_category_source') }} cat
           ON cat.id = COALESCE(us.category_id, monm.new_source_category_id) AND cat.brand_etl = cl3.brand_etl
    WHERE std.brand_etl = 1
      AND std.payment_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
)
SELECT
    a.vk,
    a.ten_dv,
    a.nguon,
    a.nhom_nguon,
    a.kenh,
    a.ngay,
    a.nhom_dv,
    CASE WHEN a.vk = 'marketing'
             THEN 'VIỆT KIỀU'
         WHEN a.chi_nhanh_raw = 'VIỆN THẨM MỸ KANGNAM BẠCH MAI'
          AND a.vk NOT IN ('marketing','mkt_oversea')
             THEN 'BỆNH VIỆN KANGNAM HÀ NỘI'
         WHEN a.chi_nhanh_raw = 'BỆNH VIỆN KANGNAM NGUYỄN TRÃI'
          AND a.vk NOT IN ('marketing','mkt_oversea')
             THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
         WHEN a.chi_nhanh_raw = 'BỆNH VIỆN KANGNAM SÀI GÒN'
          AND a.vk NOT IN ('marketing','mkt_oversea')
             THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
         WHEN a.vk = 'mkt_oversea'
             THEN 'QUỐC TẾ'
         ELSE a.chi_nhanh_raw
    END                       AS chi_nhanh,
    a.local_k,
    a.quoc_gia,
    a.doanh_so::text          AS metric,
    'DS'::text                AS type_data,
    a.ticket_id,SUBSTRING(cta.ad_id_value FROM '\d+') AS ad_id,
    a.nhom_dv_KH_quan_tam,
    a.nhom_dv_chinh_booking,
    a.nguon_moi_v2,
    a.nhom_nguon_moi_v2
FROM a
LEFT JOIN {{ source('kangnam', 'cs_ticket_api')}} cta
       ON cta.ticket_id = a.ticket_id AND cta.brand_id = 1