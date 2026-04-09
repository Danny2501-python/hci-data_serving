-- =============================================================================
-- stg_frmack_cs_services  (Pass 13)
-- Caresoft services: extract page_id and created_at from JSON detail.
-- =============================================================================
SELECT
    csa.service_id,
    csa.service_name,
    COALESCE(
        NULLIF(split_part(csa.detail, '"',   4), ''),
        NULLIF(split_part(csa.detail, '''', 4), '')
    )                                                               AS page_id,
    COALESCE(
        substring(csa.detail FROM '"created_at"\s*:\s*"([^"]+)"'),
        substring(csa.detail FROM '''created_at''\s*:\s*''([^'']+)''')
    )                                                               AS created_at
FROM {{ source('kangnam', 'cs_services_api') }} csa
WHERE csa.detail IS NOT NULL
  AND csa.brand_id = 1
  AND csa.service_type = 'Inbox Facebook'
