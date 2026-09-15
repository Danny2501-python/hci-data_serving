-- =============================================================================
-- stg_frmacpr_google
-- PASS 5: Chi phí Google Ads cho Paris.
-- =============================================================================
WITH a AS (
    SELECT
        gap.date::date                                              AS ngay_chi_phi,
        gap.cost::text                                              AS chi_phi,
        gap.campaign                                                AS campaign_raw,
        SPLIT_PART(gap.campaign, '_', 2)                           AS nhom_dv_raw,
        SPLIT_PART(gap.campaign, '_', 1)                           AS chi_nhanh_raw,
        SPLIT_PART(gap.campaign, '_', 3)                           AS extra_info
    FROM {{ source('paris', 'google_ad_paris') }} gap
    WHERE gap.date::date >= '{{ var("start_date", "2025-08-01") }}'::date
)

SELECT
    'MD - GoogleAds'::text                                            AS nguon,
    'MD'::text                                                      AS nhom_nguon,
    'Google'::text                                                     AS channel,
    ngay_chi_phi                                                    AS ngay,
    CASE
        WHEN UPPER(nhom_dv_raw) LIKE '%KHAY TRONG%'
          OR (UPPER(nhom_dv_raw) LIKE '%NIỀNG RĂNG%' AND extra_info LIKE '%TRONG SUỐT%')
          OR UPPER(nhom_dv_raw) LIKE '%NIỀNG TRONG SUỐT%'         THEN 'Niềng răng khay trong'
        WHEN UPPER(nhom_dv_raw) LIKE '%NIỀNG RĂNG%'
          OR UPPER(nhom_dv_raw) LIKE '%NIENGRANG%'              THEN 'Niềng răng mắc cài'
        WHEN UPPER(nhom_dv_raw) = 'IMPLANT'
          OR UPPER(nhom_dv_raw) = '20/6'                           THEN 'Implant'
        WHEN UPPER(nhom_dv_raw) IN ('THƯƠNG HIỆU','THƯƠNG HIÊU','THUONGHIEU')                   THEN 'THUONG HIEU'
        WHEN UPPER(nhom_dv_raw) LIKE '%RĂNG SỨ%'                  THEN 'Răng sứ'
        WHEN UPPER(nhom_dv_raw) LIKE 'PHẪU THUẬT HÀM MẶT'        THEN 'PTHM'
        ELSE UPPER(nhom_dv_raw)
    END                                                             AS nhom_dv,
    CASE UPPER(chi_nhanh_raw)
        WHEN 'BD'   THEN 'BÌNH DƯƠNG'
        WHEN 'NA'   THEN 'NGHỆ AN'
        WHEN 'QN'   THEN 'QUẢNG NINH'
        WHEN 'BV'   THEN 'HỒ CHÍ MINH'
        WHEN 'HN'   THEN 'HÀ NỘI'
        WHEN 'HP'   THEN 'QUẢNG NINH'
        WHEN 'TH'   THEN 'THANH HÓA'
        WHEN 'TN'   THEN 'THÁI NGUYÊN'
        WHEN 'VINH' THEN 'VINH'
        WHEN 'ĐN'   THEN 'ĐÀ NẴNG'
        WHEN 'BMT'  THEN 'BUÔN MÊ THUỘT'
        WHEN 'BN'   THEN 'BẮC NINH'
        WHEN 'NTH'  THEN 'HỒ CHÍ MINH'
        WHEN 'CH'   THEN 'HỒ CHÍ MINH'
        WHEN 'BT'   THEN 'HÀ NỘI'
        WHEN 'TT'   THEN 'HÀ NỘI'
        ELSE chi_nhanh_raw
    END                                                             AS chi_nhanh,
    chi_phi                                                         AS metric,
    'google'::text                                                  AS type_data,
    -- Không có liên kết CRM, nhưng nhánh này là chi phí quảng cáo Google Ads
    -- -> mặc định cứng theo catalog utm_source thật của Paris (id=735
    -- 'Google_Ads', category 'Online').
    'Google_Ads'::text                                              AS nguon_moi_v2,
    'Online'::text                                                  AS nhom_nguon_moi_v2,
    -- campaign: raw gap.campaign. actor: luôn NULL — campaign Google Ads Paris
    -- đặt tên theo {chi_nhanh}_{nhom_dv}_{extra} (token 1 = mã chi nhánh),
    -- KHÔNG theo convention 9-token all_brand_mkt_camp của FB/TikTok, nên
    -- không tách actor được (giống Google bên func_report_marketing_ad_cost_kn).
    COALESCE(campaign_raw, 'KXĐ')::text                             AS campaign,
    NULL::text                                                      AS actor_code,
    -- nhom_dv_muc_tieu_code: luôn NULL, cùng lý do với actor_code — campaign
    -- Google Ads Paris không theo convention 9-token all_brand_mkt_camp.
    NULL::text                                                      AS nhom_dv_muc_tieu_code,
    -- vk/ten_dv/local_k_raw/quoc_gia/page_id_raw/account_id_raw: thêm
    -- 2026-09-11 — nhánh Google không có liên kết CRM lẫn khái niệm FB
    -- Page/Account -> luôn NULL.
    NULL::text                                                      AS vk,
    NULL::text                                                      AS ten_dv,
    NULL::text                                                      AS local_k_raw,
    NULL::text                                                      AS quoc_gia,
    NULL::text                                                      AS page_id_raw,
    NULL::text                                                      AS account_id_raw,
    NULL::text                                                      AS page_code_raw,
    NULL::text                                                      AS nhom_dv_kh_quan_tam,
    NULL::text                                                      AS nhom_dv_chinh_booking
FROM a
