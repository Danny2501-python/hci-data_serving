-- =============================================================================
-- stg_frmack_cs_tickets  (Pass 14)
-- Caresoft tickets: pick first service_id per ticket_id.
-- ROW_NUMBER ORDER BY ticket_id (matching original, not created_at).
-- Filter: Inbox Facebook + Inbox Facebook Out; updated_at >= 2025-01-01.
-- sdt/ad_id parsed from `requester`/`ad_id_value` JSON-like text columns,
-- used by stg_frmack_deal for the DealCS block.
-- =============================================================================
SELECT
    ticket_id,
    service_id,
    created_at::date                                             AS ngay_tao,
    requester_id,
    SUBSTRING(requester FROM '"phone_no":\s*"([^"]+)"')          AS sdt,
    SUBSTRING(ad_id_value FROM '\d+')                             AS ad_id,
    ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY ticket_id) AS rnk
FROM {{ source('kangnam', 'cs_ticket_api') }}
WHERE updated_at >= '2025-01-01 00:00:00'::timestamp without time zone
  AND brand_id = 1
  AND ticket_source IN ('Inbox Facebook', 'Inbox Facebook Out')
