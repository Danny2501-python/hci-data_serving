-- =============================================================================
-- stg_bsp_cs_service_category  (Pass 2.1)
-- Lấy nhóm dịch vụ từ custom_fields của cs_contact_api (extracted_id = 6920).
-- Giá trị dạng CSV được unnest thành từng dòng riêng.
-- =============================================================================
WITH json_data AS (
    SELECT
        id,
        (jsonb_array_elements(custom_fields::jsonb) ->> 'id')::int    AS extracted_id,
        (jsonb_array_elements(custom_fields::jsonb) ->> 'value')       AS extracted_value
    FROM {{ source('paris', 'cs_contact_api') }}
    WHERE brand_id = 3
),
filtered AS (
    SELECT
        id,
        TRIM(',' FROM REPLACE(extracted_value, ' ', ''))               AS extracted_value
    FROM json_data
    WHERE extracted_id = 6920
)
SELECT
    id,
    UNNEST(string_to_array(COALESCE(extracted_value::text, '0,0'), ',')) AS extracted_value_not_null
FROM filtered
