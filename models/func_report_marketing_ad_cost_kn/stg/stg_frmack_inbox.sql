-- =============================================================================
-- stg_frmack_inbox  (Pass 9)
-- Inbox Facebook with DISTINCT (matching original col list incl. id chiến dịch)
-- cn = split_part(1) for vk/chi_nhanh checks.
-- Regular LEFT JOIN campaign_name_split (not LATERAL LIMIT 1).
-- =============================================================================

WITH a AS (
    SELECT DISTINCT
        mik."tên chiến dịch",
        mik."vùng",
        mik."id chiến dịch"::text                                    AS id_chien_dich,
        mik."ngày"::date                                             AS ngay,
        mik."người liên hệ qua nhắn tin mới",
        lka.tinh,
        lka."chi nhánh"                                              AS chi_nhanh_qc,
        lka.ngay_hh,
        CASE 
            WHEN cardinality(string_to_array(mik."tên chiến dịch",'_' )) >= 9 
                and TRIM(split_part(mik."tên chiến dịch", '_', 1)) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 2)
        END                                                          AS page_code,
        CASE 
            WHEN cardinality(string_to_array(mik."tên chiến dịch",'_' )) >= 9 
                and TRIM(split_part(mik."tên chiến dịch", '_', 1)) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 3)
            ELSE TRIM(split_part(mik."tên chiến dịch", '_', 1))
        END                                                          AS cn,
        CASE 
            WHEN cardinality(string_to_array(mik."tên chiến dịch",'_' )) >= 9 
                and split_part(mik."tên chiến dịch", '_', 1) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 5)
            ELSE UPPER(TRIM(split_part(mik."tên chiến dịch", '_', 2)))
        END                                                          AS nhom_dv_qc,
        CASE 
            WHEN cardinality(string_to_array(mik."tên chiến dịch",'_' )) >= 9 
                and split_part(mik."tên chiến dịch", '_', 1) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 8)
            ELSE NULL
        END                                                          AS camp_actor,
        mik."vùng"                                                   AS local,
        da.account_name                                            as account_fb,
        fccm.continent_vn,fccm.country_name_vn
    FROM {{ source('kangnam', 'm_inbox_kangnam') }} mik
    LEFT JOIN LATERAL (
        SELECT lka1.tinh, lka1."chi nhánh", lka1.ngay_hh
        FROM {{ source('kangnam', 'location_kangnam_adnet') }} lka1
        WHERE lka1.tinh = mik."vùng"
          AND mik."ngày"::date >= lka1.ngay_hh
        ORDER BY lka1.ngay_hh DESC LIMIT 1
    ) lka ON TRUE
    LEFT JOIN {{ref('dim_campaign')}} dc
        ON dc.campaign_id = mik."id chiến dịch"::text
    LEFT JOIN {{ref('dim_account')}} da
        ON da.account_id = dc.ad_account_id
    LEFT JOIN {{ref('dim_region')}} dr 
        ON dr.region = mik."vùng"
    LEFT JOIN {{source('kangnam','fb_country_code_mapping')}} fccm
        ON dr.country = fccm.country_code
    WHERE mik."ngày"::date >= '{{ var("start_date", "2025-08-01") }}'::date
),
i AS (
    SELECT
        CASE WHEN a.cn ILIKE '%Hai Ngoai%' or a.cn = 'vki' THEN 'VIỆT KIỀU'
             WHEN a.cn ILIKE '%QUOC TE%' or a.cn = 'qte' THEN 'QUỐC TẾ'
             WHEN a.cn = 'exp' THEN 'exp'
             ELSE 'no'
        END                                                          AS vk,
        a.local,
        a."tên chiến dịch"                                           AS campaign_name,
        a.ngay,
        cns.nhom_dv                                                  AS nhom_dv_sys,
        CASE WHEN a.chi_nhanh_qc IS NULL AND a.cn NOT ILIKE '%QUOC TE%' THEN 'VIỆT KIỀU'
             WHEN a.chi_nhanh_qc IS NULL AND a.cn     ILIKE '%QUOC TE%' THEN 'QUỐC TẾ'
             ELSE a.chi_nhanh_qc
        END                                                          AS chi_nhanh_inter,
        a."người liên hệ qua nhắn tin mới"::text                    AS metric,
        a.camp_actor,a.account_fb,
        upc.page_name  ,upc.page_id,a.continent_vn,a.country_name_vn
    FROM a
    -- Regular LEFT JOIN (not LATERAL) — matching original Pass 9
    LEFT JOIN {{ source('kangnam', 'campaign_name_split') }} cns
           ON UPPER(cns.campain_name_split) = UPPER(a.nhom_dv_qc)
    LEFT JOIN {{ source('kangnam', 'ucbt_page_config') }} upc
           ON upc.page_code = a.page_code
    WHERE a."người liên hệ qua nhắn tin mới" IS NOT NULL
)
SELECT
    i.vk,
    'DV'::text   AS ten_dv,
    'IB'::text   AS nguon,
    'IB'::text   AS nhom_nguon,
    'FB'::text   AS kenh,
    i.ngay,
    i.nhom_dv_sys AS nhom_dv,
    CASE i.chi_nhanh_inter
        WHEN 'HÀ NỘI' THEN 'BỆNH VIỆN KANGNAM HÀ NỘI'
        ELSE CASE UPPER(i.chi_nhanh_inter)
            WHEN 'HCM'            THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
            WHEN 'VK'             THEN 'VIỆT KIỀU'
            WHEN 'VIỆT KIỀU'     THEN 'VIỆT KIỀU'
            WHEN 'BẮC NINH'      THEN 'VIỆN THẨM MỸ KANGNAM BẮC NINH'
            WHEN 'HẢI PHÒNG'     THEN 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'
            WHEN 'BUÔN MÊ THUỘT' THEN 'VIỆN THẨM MỸ KANGNAM BUÔN MA THUỘT'
            WHEN 'ĐÀ NẴNG'       THEN 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'
            WHEN 'CẦN THƠ'       THEN 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'
            WHEN 'NGHỆ AN'       THEN 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'
            WHEN 'THÁI NGUYÊN'   THEN 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN'
            WHEN 'THANH HÓA'     THEN 'VIỆN THẨM MỸ KANGNAM THANH HÓA'
            WHEN 'BÌNH DƯƠNG'    THEN 'VIỆN THẨM MỸ KANGNAM BÌNH DƯƠNG'
            ELSE UPPER(i.chi_nhanh_inter)
        END
    END           AS chi_nhanh,
    CASE i.local
        WHEN 'Ho Chi Minh City' THEN 'SÀI GÒN'
        WHEN 'Hanoi'            THEN 'Hà Nội'
        WHEN 'Da Nang'          THEN 'Thành phố Đà Nẵng'
        WHEN 'Cần Thơ'          THEN 'Thành phố Cần Thơ'
        WHEN 'Haiphong'         THEN 'Thành phố Hải Phòng'
        ELSE CASE
            WHEN i.chi_nhanh_inter = 'VIỆT KIỀU' THEN i.continent_vn
            WHEN i.chi_nhanh_inter = 'QUỐC TẾ'  THEN i.continent_vn
            ELSE 'Tỉnh ' || regexp_replace(i.local, '\s*Province$', '')
        END
    END           AS local_k,
    CASE WHEN i.chi_nhanh_inter = 'VIỆT KIỀU' THEN i.country_name_vn
         WHEN i.chi_nhanh_inter = 'QUỐC TẾ'  THEN i.country_name_vn
         ELSE 'Việt Nam'
    END           AS quoc_gia,
    i.metric,
    'inbox'::text AS type_data,
    0             AS ticket_id,
    i.page_name,i.page_id,i.campaign_name,
    i.camp_actor,i.account_fb
FROM i
