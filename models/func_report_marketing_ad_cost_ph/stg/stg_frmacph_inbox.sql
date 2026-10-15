{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_inbox
-- Inbox (người liên hệ nhắn tin mới) của campaign 'sun_' từ m_inbox_sunwoo.
-- [2026-10-06] Đổi nguồn từ m_inbox_kangnam → m_inbox_sunwoo: các dòng 'sun_' đã được
-- chuyển hẳn sang bảng mới (m_inbox_kangnam còn 0 dòng 'sun_'); số 19–29/09 khớp số cũ.
-- Cột "chi phí facebook" của bảng mới KHÔNG dùng: chi phí vẫn lấy từ cs_facebook_insight
-- (đầy đủ hơn – bảng inbox chỉ ghi vùng có inbox, thấp hơn vài trăm nghìn/ngày).
-- [2026-10-08] BỎ cột "vùng": từ lần nạp 08/10 16:05, sheet inbox Sunwoo tổng hợp theo campaign,
-- cột "vùng" trống toàn bộ (kiểu dữ liệu bị đổi thành số → lỗi build). Model không đọc cột này
-- nữa (vung = NULL → local_k / tinh_noi của inbox = 'KXĐ'), theo yêu cầu user.
-- [2026-10-09] CHỐNG NẠP TRÙNG: sáng 09/10 cùng snapshot bị nạp 2 lần (492 dòng / 246 khoá) →
-- inbox nhân đôi. Với mỗi ngày × id chiến dịch chỉ lấy dữ liệu của LẦN NẠP MỚI NHẤT
-- (ingestion_timestamp lớn nhất) → nguồn có nạp trùng cũng không nhân đôi.
-- =============================================================================
SELECT
    nullif(trim(m."ngày"), '')::date               AS ngay,
    m."id chiến dịch"::text                         AS campaign_id,
    m."tên chiến dịch"                              AS camp_name,
    NULL::text                                      AS vung,       -- bỏ "vùng" (2026-10-08)
    split_part(m."tên chiến dịch", '_', 2)          AS page_code,
    split_part(m."tên chiến dịch", '_', 3)          AS cn,
    split_part(m."tên chiến dịch", '_', 5)          AS nhom_dv_code,
    split_part(m."tên chiến dịch", '_', 8)          AS actor_code,
    m."người liên hệ qua nhắn tin mới"              AS inbox_moi
FROM (
    SELECT x.*,
           max(x.ingestion_timestamp) OVER (
               PARTITION BY x."ngày", x."id chiến dịch") AS lan_nap_moi_nhat
    FROM {{ source('sunwoo', 'm_inbox_sunwoo') }} x
) m
WHERE m."tên chiến dịch" ILIKE 'sun\_%'
  AND m."người liên hệ qua nhắn tin mới" IS NOT NULL
  AND m.ingestion_timestamp = m.lan_nap_moi_nhat          -- chỉ lần nạp mới nhất (chống trùng)
