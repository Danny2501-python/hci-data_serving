{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_pancake — 1 dòng / hội thoại Pancake của Sunwoo (brand_id = 9)
-- + thông tin quảng cáo khách bấm vào để nhắn tin (first_ad_id) → campaign/adset/ad/
-- tài khoản quảng cáo, tra từ dữ liệu chi phí FB campaign 'sun_' (cs_facebook_insight).
-- Dùng để gắn campaign/page cho lead ERP PH:
--   ph.crm_lead.pancake_conversation_id = conversation_id (khoá duy nhất, đã kiểm tra
--   2026-10-08: 2.554 dòng = 2.554 khoá; conversation_id đã gồm tiền tố page).
-- Thêm 2026-10-08 (dữ liệu Pancake đổ về DB từ 2026-10-07).
-- =============================================================================
WITH ad_map AS (        -- ad_id → campaign / adset / ad / tài khoản (lấy tên mới nhất)
    SELECT DISTINCT ON (f.ad_id)
        f.ad_id,
        f.ad_campaign_id     AS campaign_id,
        f.ad_campaign_name   AS campaign_name,
        f.adset_name,
        f.ad_name,
        f.ad_account_name    AS account_fb
    FROM {{ source('kangnam', 'cs_facebook_insight') }} f
    WHERE f.brand_etl = 1
      AND f.ad_campaign_name ILIKE 'sun\_%'
    ORDER BY f.ad_id, f."date" DESC
)
SELECT
    c.conversation_id,
    c.page_id,
    p.page_name,
    p.platform,
    c.inserted_date_vn                                  AS ngay_hoi_thoai,
    c.is_from_ad,
    c.first_ad_id,
    a.campaign_id,
    a.campaign_name,
    a.adset_name,
    a.ad_name,
    a.account_fb,
    split_part(a.campaign_name, '_', 5)                 AS nhom_dv_code,
    split_part(a.campaign_name, '_', 8)                 AS actor_code
FROM {{ source('pancake', 'pancake_conversation') }} c
LEFT JOIN {{ source('pancake', 'core_pancake_page') }} p ON p.page_id = c.page_id
LEFT JOIN ad_map a ON a.ad_id = c.first_ad_id
WHERE c.brand_id = 9
