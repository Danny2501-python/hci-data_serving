{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_inbox
-- Inbox (người liên hệ nhắn tin mới) của campaign 'sun_' từ m_inbox_sunwoo.
-- [2026-10-06] Đổi nguồn từ m_inbox_kangnam → m_inbox_sunwoo: các dòng 'sun_' đã được
-- chuyển hẳn sang bảng mới (m_inbox_kangnam còn 0 dòng 'sun_'); số 19–29/09 khớp số cũ.
-- Cột "chi phí facebook" của bảng mới KHÔNG dùng: chi phí vẫn lấy từ cs_facebook_insight
-- (đầy đủ hơn – bảng inbox chỉ ghi vùng có inbox, thấp hơn vài trăm nghìn/ngày).
-- =============================================================================
SELECT
    nullif(trim(m."ngày"), '')::date               AS ngay,
    m."id chiến dịch"::text                         AS campaign_id,
    m."tên chiến dịch"                              AS camp_name,
    m."vùng"                                        AS vung,
    split_part(m."tên chiến dịch", '_', 2)          AS page_code,
    split_part(m."tên chiến dịch", '_', 3)          AS cn,
    split_part(m."tên chiến dịch", '_', 5)          AS nhom_dv_code,
    split_part(m."tên chiến dịch", '_', 8)          AS actor_code,
    m."người liên hệ qua nhắn tin mới"              AS inbox_moi
FROM {{ source('sunwoo', 'm_inbox_sunwoo') }} m
WHERE m."tên chiến dịch" ILIKE 'sun\_%'
  AND m."người liên hệ qua nhắn tin mới" IS NOT NULL
