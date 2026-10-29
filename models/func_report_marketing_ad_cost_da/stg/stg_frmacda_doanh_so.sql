{{
  config(
    materialized = 'ephemeral'
  )
}}

-- =============================================================================
-- stg_frmacda_doanh_so — bản ĐÔNG Á của stg_frmack_doanh_so (Kangnam).
-- Doanh số (DS) từ stag_payment_transfer brand_etl = 2 (có từ 06/09/2026).
--
-- Khác bản Kangnam: giống các điểm 1-6 ở stg_frmacda_crm_base.sql
-- (brand 2, chưa có CareSoft, MD - Search -> Web, tỉnh/quốc gia fallback brand 1,
-- nguồn tra theo danh mục Kangnam brand 1, không remap chi nhánh).
-- =============================================================================

WITH a AS (
    SELECT
        CASE
            WHEN cl3.overseas_vietnamese = 'expat' THEN 'exp'
            ELSE cl3.overseas_vietnamese
        END                                            AS vk,
        sp.product                                     AS ten_dv,
        COALESCE(ss.source, uso.name)                  AS nguon,
        COALESCE(ss.category_source, cso.name)         AS nhom_nguon,
        CASE
            WHEN COALESCE(ss.source, uso.name) IN ('MD - Tiktok', 'MD - Zalo', 'MKT_Zalo', 'MD - Youtube',
                               'MD - Phát triển cộng đồng (Seeding)', 'MD - Phát triển cộng đồng')
                 THEN 'Khác'
            WHEN COALESCE(ss.source, uso.name) ~~ '%Facebook%' THEN 'FB'
            WHEN COALESCE(ss.source, uso.name) = 'MD - Search' THEN 'Web'
            WHEN COALESCE(ss.source, uso.name) ~~ '%Seo%'      THEN 'Web'
            WHEN COALESCE(ss.source, uso.name) ~~ '%Google%'   THEN 'Web'
            WHEN COALESCE(ss.source, uso.name) ~~ '%Hotline%'  THEN 'Web'
            ELSE 'Khác'
        END                                            AS kenh,
        std.payment_date                               AS ngay,
        mrc.name                                       AS chi_nhanh_raw,
        std.payment                                    AS doanh_so,
        sp.product_category                            AS nhom_dv,
        COALESCE(rcs2.name, rcs1.name)                 AS state_name,
        COALESCE(rcs2.code, rcs1.code)                 AS state_code,
        COALESCE(rc2.name, rc1.name)                   AS quoc_gia,
        cl3.ticket_id,
        dkq.first_product_group                        AS nhom_dv_KH_quan_tam,
        dkq.first_product_category                     AS nhom_dv_KH_quan_tam_goc,
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
        END                                            AS nhom_dv_chinh_booking,
        COALESCE(us.name, monm.new_source_name)        AS nguon_moi_v2,
        cat.name                                       AS nhom_nguon_moi_v2
    FROM {{ source('kangnam', 'stag_payment_transfer') }} std
    LEFT JOIN {{ source('kangnam', 'crm_lead') }} cl3
           ON std.crm_id = cl3.id AND std.brand_etl = cl3.brand_etl
    LEFT JOIN {{ source('kangnam', 'res_country_state') }} rcs2
           ON rcs2.id = cl3.state_id AND rcs2.brand_etl = 2
    LEFT JOIN {{ source('kangnam', 'res_country_state') }} rcs1
           ON rcs1.id = cl3.state_id AND rcs1.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'res_country') }} rc2
           ON rc2.id = cl3.country_id AND rc2.brand_etl = 2
    LEFT JOIN {{ source('kangnam', 'res_country') }} rc1
           ON rc1.id = cl3.country_id AND rc1.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'view_stag_products') }} sp
           ON sp.product_id = std.product_id AND sp.brand_etl = std.brand_etl
    -- Nguồn: stag_sources brand_id = 1, dự phòng bằng danh mục riêng của Đông Á
    -- (xem mục 4 ở common/stg_common_tongquan_khachhang_da.sql)
    LEFT JOIN {{ source('kangnam', 'stag_sources') }} ss
           ON ss.old_id = cl3.source_id::double precision AND ss.brand_id = 1
    LEFT JOIN LATERAL (
        SELECT u.name, u.category_id
        FROM {{ source('kangnam', 'utm_source') }} u
        WHERE u.id = cl3.source_id AND u.brand_etl = 2
        LIMIT 1
    ) uso ON TRUE
    LEFT JOIN {{ source('kangnam', 'crm_category_source') }} cso
           ON cso.id = uso.category_id AND cso.brand_etl = 2
    LEFT JOIN {{ source('kangnam', 'm_res_company') }} mrc
           ON mrc.id = std.company_id AND mrc.brand_etl = 2
    LEFT JOIN {{ ref('stg_dv_khach_hang_quan_tam_da') }} dkq
           ON dkq.crm_id = cl3.id AND dkq.brand_etl = cl3.brand_etl
    LEFT JOIN {{ ref('stg_booking_nhom_dich_vu_chinh_da') }} sbn
           ON sbn.crm_id = cl3.id AND sbn.brand_etl = cl3.brand_etl
    LEFT JOIN LATERAL (
        SELECT u.name, u.category_id
        FROM {{ source('kangnam', 'utm_source') }} u
        WHERE u.id = cl3.new_source_id AND u.brand_etl = 2
        LIMIT 1
    ) us ON TRUE
    LEFT JOIN LATERAL (
        SELECT m.new_source_name, m.new_source_category_id, m.brand_etl AS map_brand
        FROM {{ ref('m_utm_source_old_new_map') }} m
        WHERE m.old_source_id = cl3.source_id AND m.brand_etl IN (2, 1)
          AND us.name IS NULL
        ORDER BY (m.brand_etl = 2) DESC, m.new_source_id
        LIMIT 1
    ) monm ON TRUE
    LEFT JOIN {{ source('kangnam', 'crm_category_source') }} cat
           ON cat.id = COALESCE(us.category_id, monm.new_source_category_id)
          AND cat.brand_etl = CASE WHEN us.category_id IS NOT NULL THEN 2 ELSE monm.map_brand END
    WHERE std.brand_etl = 2
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
    CASE WHEN a.vk = 'marketing'   THEN 'VIỆT KIỀU'
         WHEN a.vk = 'mkt_oversea' THEN 'QUỐC TẾ'
         ELSE a.chi_nhanh_raw
    END                       AS chi_nhanh,
    CASE WHEN a.state_name = 'Thành phố Hồ Chí Minh' THEN 'SÀI GÒN'
         WHEN a.state_name = 'Thành phố Hà Nội'       THEN 'Hà Nội'
         WHEN a.state_name IS NULL                      THEN 'KXĐ'
         WHEN a.state_code NOT LIKE '%VN-%'             THEN 'VIỆT KIỀU'
         ELSE a.state_name
    END                       AS local_k,
    a.quoc_gia,
    a.doanh_so::text          AS metric,
    'DS'::text                AS type_data,
    a.ticket_id,
    NULL::text                AS ad_id,
    a.nhom_dv_KH_quan_tam,
    a.nhom_dv_KH_quan_tam_goc,
    a.nhom_dv_chinh_booking,
    a.nguon_moi_v2,
    a.nhom_nguon_moi_v2
FROM a
