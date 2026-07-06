-- =============================================================================
-- stg_bsp_cs_company  (Pass 2.2)
-- Lấy chi nhánh từ custom_fields của cs_ticket_api (extracted_id = 5981).
-- Group by ticket_id để lấy custom_fields mới nhất, rồi unnest JSON array.
-- =============================================================================
WITH temp_1 AS (
    SELECT
        ticket_id,
        MAX(custom_fields) AS custom_fields
    FROM {{ source('paris', 'cs_ticket_api') }}
    WHERE brand_id = 3
    GROUP BY ticket_id
),
temp_2 AS (
    SELECT
        ticket_id,
        (jsonb_array_elements(custom_fields::jsonb) ->> 'id')::int    AS extracted_id,
        jsonb_array_elements(custom_fields::jsonb) ->> 'value'         AS extracted_value
    FROM temp_1
)
SELECT
    ticket_id,
    TRIM(',' FROM REPLACE(extracted_value, ' ', ''))                   AS extracted_value
FROM temp_2
WHERE extracted_value <> '-1'
  AND extracted_id = 5981
