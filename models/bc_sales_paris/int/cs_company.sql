
with temp_1 as (
    select
        ticket_id,
        count(*),
        max(custom_fields) as custom_fields,
        max(updated_at) as updated_at
    from
        {{ source('paris_raw', 'cs_ticket_api') }} cta
    where
        brand_id = 3
    group by
        ticket_id
    ),temp_2 as (
    select
        ticket_id,
        (jsonb_array_elements(custom_fields::jsonb)->>'id')::int as extracted_id,
        jsonb_array_elements(custom_fields::jsonb)->>'value' as extracted_value
    from
        temp_1)
    select
        ticket_id,
        extracted_id,
        TRIM(',' from replace(extracted_value, ' ', '')) as extracted_value
    from
        temp_2
    where
        extracted_value <> '-1' and extracted_id = '5981' 
