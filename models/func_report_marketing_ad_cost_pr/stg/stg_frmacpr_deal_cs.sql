-- =============================================================================
-- stg_frmacpr_deal_cs
-- PASS x: Số deal nguồn google ads.
-- =============================================================================
WITH ticket_cs_gg AS (
SELECT 
    'MD - GoogleAds'                                                            AS nguon,
    'MD'                                                                        AS nhom_nguon,
    'Google'                                                                    AS kenh,
    cta.created_at::date                                                        AS ngay,
    COALESCE(SPLIT_PART(ggcal.campaign_name, '_', 2),ctsda.utm_campaign)        AS nhom_dv,
    COALESCE(SPLIT_PART(ggcal.campaign_name, '_', 1),ctsda.utm_content)         AS chi_nhanh,
    COALESCE(SPLIT_PART(ggcal.campaign_name, '_', 3),ctsda.utm_content)         AS extra_info,
    COALESCE(ggcal.campaign_name, ctsda.utm_campaign)                           AS campaign_raw,
    substring(cta.requester FROM '"phone_no":\s*"(\d+)"')                       AS metric,
    'Deal_cs'                                                                   AS type_data
FROM {{ source('paris', 'cs_ticket_api')}}                          cta
LEFT JOIN {{ source('paris', 'cs_ticket_source_api')}}              ctsa
       ON cta.ticket_id = ctsa.ticket_id
LEFT JOIN {{ source('paris', 'cs_ticket_source_detail_api')}}       ctsda
       ON ctsa.ticket_source_detail_id = ctsda.id  
LEFT JOIN {{ source('paris', 'ggs_google_campaign_ads_list')}}      ggcal
        ON ctsda.utm_campaign = ggcal.campaign_id::text 
WHERE ctsda.utm_source ilike '%Google_Search%' 
        AND cta.created_at >= '2025-08-01' 
        AND cta.brand_id = 3
)
SELECT tcg.nguon, tcg.nhom_nguon,tcg.kenh,tcg.ngay,
     CASE
        WHEN UPPER(tcg.nhom_dv) LIKE '%KHAY TRONG%'
          OR (UPPER(tcg.nhom_dv) LIKE '%NIỀNG RĂNG%' AND extra_info LIKE '%TRONG SUỐT%')
          OR UPPER(tcg.nhom_dv) LIKE '%NIỀNG TRONG SUỐT%'                                               THEN 'Niềng răng khay trong'
        WHEN UPPER(tcg.nhom_dv) LIKE '%NIỀNG RĂNG%'
          OR UPPER(tcg.nhom_dv) LIKE '%NIENGRANG%'                                                      THEN 'Niềng răng mắc cài'
        WHEN UPPER(tcg.nhom_dv) = 'IMPLANT'
          OR UPPER(tcg.nhom_dv) = '20/6'                                                                THEN 'Implant'
        WHEN UPPER(tcg.nhom_dv) IN ('THƯƠNG HIỆU','THƯƠNG HIÊU','THUONGHIEU')                           THEN 'THUONG HIEU'
        WHEN UPPER(tcg.nhom_dv) LIKE '%RĂNG SỨ%' OR UPPER(tcg.nhom_dv) = 'BOCRANGSU'                    THEN 'Răng sứ'
        WHEN UPPER(tcg.nhom_dv) LIKE 'PHẪU THUẬT HÀM MẶT' OR UPPER(tcg.nhom_dv) = 'PHAUTHUATHAM'        THEN 'PTHM'
        ELSE UPPER(tcg.nhom_dv)
    END                                                             AS nhom_dv,
    CASE 
        WHEN UPPER(tcg.chi_nhanh) IN ('BD','BÌNH DƯƠNG')        THEN 'BÌNH DƯƠNG'
        WHEN UPPER(tcg.chi_nhanh) IN ('NA','NGHỆ AN')           THEN 'NGHỆ AN'
        WHEN UPPER(tcg.chi_nhanh) IN ('QN','QUẢNG NINH')        THEN 'QUẢNG NINH'
        WHEN UPPER(tcg.chi_nhanh) IN ('BV','HỒ CHÍ MINH')       THEN 'HỒ CHÍ MINH'
        WHEN UPPER(tcg.chi_nhanh) IN ('HN','HÀ NỘI')            THEN 'HÀ NỘI'
        WHEN UPPER(tcg.chi_nhanh) IN ('HP','QUẢNG NINH')        THEN 'QUẢNG NINH'
        WHEN UPPER(tcg.chi_nhanh) IN ('TH','THANH HÓA')         THEN 'THANH HÓA'
        WHEN UPPER(tcg.chi_nhanh) IN ('TN','THÁI NGUYÊN')       THEN 'THÁI NGUYÊN'
        WHEN UPPER(tcg.chi_nhanh) = 'VINH'                      THEN 'VINH'
        WHEN UPPER(tcg.chi_nhanh) IN ('ĐN','DN','ĐÀ NẴNG')      THEN 'ĐÀ NẴNG'
        WHEN UPPER(tcg.chi_nhanh) IN ('BMT','BUÔN MÊ THUỘT')    THEN 'BUÔN MÊ THUỘT'
        WHEN UPPER(tcg.chi_nhanh) IN ('BN','BẮC NINH')          THEN 'BẮC NINH'
        WHEN UPPER(tcg.chi_nhanh) IN ('NTH','CH','HỒ CHÍ MINH','HCM') THEN 'HỒ CHÍ MINH'
        WHEN UPPER(tcg.chi_nhanh) IN ('BT','TT','HÀ NỘI')       THEN 'HÀ NỘI'
        WHEN tcg.chi_nhanh IS NULL then 'KHÔNG XÁC ĐỊNH'
        ELSE chi_nhanh
    END                                                             AS chi_nhanh,
    tcg.metric,
    tcg.type_data,
    COALESCE(tcg.campaign_raw, 'KXĐ')::text                             AS campaign,
    -- actor: nhánh Deal_cs Paris lấy theo tiêu chí Google Search
    -- (ctsda.utm_source ilike '%Google_Search%'), không phải campaign FB
    -- theo convention 9-token -> luôn NULL, giống nhánh GG (Google) của model
    -- này và cách func_report_marketing_ad_cost_kn xử lý Google.
    NULL::text                                                          AS actor_code,
    -- nhom_dv_muc_tieu_code: cùng lý do actor_code, luôn NULL.
    NULL::text                                                          AS nhom_dv_muc_tieu_code,
    -- vk/ten_dv/local_k_raw/quoc_gia/page_id_raw/account_id_raw: thêm
    -- 2026-09-11 — nhánh Deal_cs không có liên kết CRM lẫn khái niệm FB
    -- Page/Account -> luôn NULL.
    NULL::text                                                          AS vk,
    NULL::text                                                          AS ten_dv,
    NULL::text                                                          AS local_k_raw,
    NULL::text                                                          AS quoc_gia,
    NULL::text                                                          AS page_id_raw,
    NULL::text                                                          AS account_id_raw,
    NULL::text                                                          AS page_code_raw,
    NULL::text                                                          AS nhom_dv_kh_quan_tam,
    NULL::text                                                          AS nhom_dv_chinh_booking
FROM ticket_cs_gg tcg
WHERE tcg.metric IS NOT NULL