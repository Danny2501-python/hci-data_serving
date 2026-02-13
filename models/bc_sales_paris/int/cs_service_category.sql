
with n as (WITH json_data AS (
    select
    id ,
    updated_at,
        (jsonb_array_elements(custom_fields::jsonb)->>'id')::int AS extracted_id,
        (jsonb_array_elements(custom_fields::jsonb)->>'value') AS extracted_value
    FROM
        {{ source('paris_raw', 'cs_contact_api') }} cca 
)
select
        id ,
        updated_at,
    extracted_id,
    TRIM(',' FROM REPLACE(extracted_value, ' ', '')) AS extracted_value
FROM  json_data
WHERE
    extracted_id = 6920)
select n.id,
unnest (string_to_array (coalesce(extracted_value::text, '0,0'), ',')) as extracted_value_not_null
from n
