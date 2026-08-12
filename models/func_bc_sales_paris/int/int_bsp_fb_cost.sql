-- =============================================================================
-- int_bsp_fb_cost  (Pass 11)
-- Chi phí Facebook Ads cho Paris (account id IN 7,8,9).
-- Quy đổi USD → VND: spend * 23500.
-- chi_nhanh map từ viết tắt (segment 1 của tên ad set) → tên đầy đủ.
-- nhom_dv lấy từ segment 2 của tên ad set.
-- =============================================================================
WITH base AS (
    SELECT
        cfaai."date"                                                   AS ngay_chi_phi,
        CASE WHEN cfaai.fb_account_currency = 'USD'
             THEN cfaai.spend * 23500
             ELSE cfaai.spend
        END                                                            AS metric,
        cfaai.fb_ad_ad_id                                              AS ad_id,
        cfac2.name                                                     AS camp_name,
        cfaa2.name                                                     AS acc_name,
        split_part(cfas.name, '_', 2)                                  AS nhom_dv,
        split_part(cfas.name, '_', 1)                                  AS chi_nhanh_raw,
        1 thu_tu,
        0 line_id,
        0 tong_tien
    FROM {{ source('paris', 'core_facebook_ad_ad_insight') }} cfaai
    LEFT JOIN {{ source('paris', 'core_facebook_ad_ad') }} cfaa
           ON cfaa.fb_ad_ad_id = cfaai.fb_ad_ad_id
    LEFT JOIN {{ source('paris', 'core_facebook_ad_set') }} cfas
           ON cfas.fb_ad_set_id = cfaa.fb_ad_set_id
    LEFT JOIN {{ source('paris', 'core_facebook_ad_campaign') }} cfac2
           ON cfac2.fb_ad_campaign_id = cfas.fb_ad_campaign_id
    LEFT JOIN {{ source('paris', 'core_facebook_ad_account') }} cfaa2
           ON cfaa2.ad_account_id = cfac2.fb_ad_account_id
    WHERE cfaa2.id IN (7, 8, 9)
      AND cfaai."date" > '2022-01-01'
)
SELECT
    'ad'::text                                                         AS ad_id,
    'Chi_phi'::text                                                    AS bang,
    'text'::text                                                       AS ticket_id,
    TEXT(metric)                                                       AS requester_id,
    'nhanvien'::text                                                   AS nv,
    'email'::text                                                      AS work_email,
    DATE(ngay_chi_phi)                                                 AS date,
    'Facebook'::text                                                   AS nguon,
    CASE UPPER(chi_nhanh_raw)
        WHEN 'HN'        THEN 'HÀ NỘI'
        WHEN 'HCM'       THEN 'HỒ CHÍ MINH'
        WHEN 'VK'        THEN 'Việt Kiều'
        WHEN 'VIET KIEU' THEN 'Việt Kiều'
        WHEN 'BN'        THEN 'NHA KHOA PARIS BẮC NINH'
        WHEN 'HP'        THEN 'NHA KHOA PARIS HẢI PHÒNG'
        WHEN 'BMT'       THEN 'NHA KHOA PARIS BUÔN MÊ THUỘT'
        WHEN 'ĐN'        THEN 'NHA KHOA PARIS ĐÀ NẴNG'
        WHEN 'CH'        THEN 'HỒ CHÍ MINH'
        WHEN 'VINH'      THEN 'NHA KHOA PARIS VINH'
        WHEN 'TN'        THEN 'NHA KHOA PARIS THÁI NGUYÊN'
        WHEN 'TH'        THEN 'NHA KHOA PARIS THANH HÓA'
        WHEN 'BD'        THEN 'NHA KHOA PARIS BÌNH DƯƠNG'
        WHEN 'QN'        THEN 'NHA KHOA PARIS QUẢNG NINH'
        WHEN 'BV'        THEN 'HỒ CHÍ MINH'
        WHEN 'NTH'       THEN 'HỒ CHÍ MINH'
        ELSE UPPER(chi_nhanh_raw)
    END                                                                AS chi_nhanh,
    nhom_dv,
    'ten_khach'::text                                                  AS ten_khach,
    'ma_booking'::text                                                 AS ma_booking,
    'phong_ban'::text                                                  AS phong_ban,
    thu_tu,
    line_id,
    tong_tien,
    0 crm_id
FROM base
