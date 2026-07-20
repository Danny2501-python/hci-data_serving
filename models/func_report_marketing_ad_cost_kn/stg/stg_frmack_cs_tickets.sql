-- =============================================================================
-- stg_frmack_cs_tickets  (Pass 14)
-- Caresoft tickets: pick first service_id per ticket_id.
-- ROW_NUMBER ORDER BY ticket_id (matching original, not created_at).
-- Filter: Inbox Facebook + Inbox Facebook Out; updated_at >= 2025-01-01.
-- sdt/ad_id parsed from `requester`/`ad_id_value` JSON-like text columns,
-- used by stg_frmack_deal for the DealCS block.
-- nhom_dv_chinh_cs = `value` của phần tử có id = 9794 (label "Nhóm dịch vụ
-- chính") trong JSON array `custom_fields`, lấy qua LATERAL + LIMIT 1 để
-- không nhân dòng (custom_fields luôn là JSON array hợp lệ, không NULL/NaN).
-- Tạm comment (chưa dùng ở downstream) — xem README mục 12, knowledge.md.
-- =============================================================================
SELECT
    cta.ticket_id,
    cta.service_id,
    cta.created_at::date                                         AS ngay_tao,
    cta.requester_id,
    SUBSTRING(cta.requester FROM '"phone_no":\s*"([^"]+)"')      AS sdt,
    SUBSTRING(cta.ad_id_value FROM '\d+')                         AS ad_id,
    -- ndc.nhom_dv_chinh_cs,
    ROW_NUMBER() OVER (PARTITION BY cta.ticket_id ORDER BY cta.ticket_id) AS rnk
FROM {{ source('kangnam', 'cs_ticket_api') }} cta
-- LEFT JOIN LATERAL (
--     SELECT elem ->> 'value' AS nhom_dv_chinh_cs
--     FROM jsonb_array_elements(cta.custom_fields::jsonb) AS elem
--     WHERE (elem ->> 'id')::int = 9794
--     LIMIT 1
-- ) ndc ON TRUE
WHERE cta.updated_at >= '2025-01-01 00:00:00'::timestamp without time zone
  AND cta.brand_id = 1
  AND cta.ticket_source IN ('Inbox Facebook', 'Inbox Facebook Out')
