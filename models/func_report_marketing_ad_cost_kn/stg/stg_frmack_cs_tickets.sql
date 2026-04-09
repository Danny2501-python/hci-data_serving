-- =============================================================================
-- stg_frmack_cs_tickets  (Pass 14)
-- Caresoft tickets: pick first service_id per ticket_id.
-- ROW_NUMBER ORDER BY ticket_id (matching original, not created_at).
-- Filter: Inbox Facebook + Inbox Facebook Out; updated_at >= 2025-01-01.
-- =============================================================================
SELECT
    ticket_id,
    service_id,
    ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY ticket_id) AS rnk
FROM {{ source('kangnam', 'cs_ticket_api') }}
WHERE updated_at >= '2025-01-01 00:00:00'::timestamp without time zone
  AND brand_id = 1
  AND ticket_source IN ('Inbox Facebook', 'Inbox Facebook Out')
