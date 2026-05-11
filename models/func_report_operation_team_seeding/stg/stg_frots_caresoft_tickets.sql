{% set start_date = var('start_date', '2025-08-01') %}

SELECT DISTINCT ON (cta.ticket_id)
    cta.ticket_id,
    TRIM(BOTH FROM SPLIT_PART(ccf.value_lable, ']', 2)) AS nhanvien_seeding,
    cta.brand_id,
    cta.created_at,
    CASE WHEN cta.requester = 'NaN' THEN NULL ELSE (cta.requester::jsonb ->> 'phone_no') END AS phone,
    CASE WHEN cta.requester = 'NaN' THEN NULL ELSE (cta.requester::jsonb ->> 'username') END AS customer,
    cta.updated_at
FROM {{ source('frots', 'cs_ticket_api') }} cta
CROSS JOIN LATERAL jsonb_array_elements(cta.custom_fields::jsonb) AS cf(item)
LEFT JOIN {{ source('frots', 'cs_custom_fields') }} ccf ON ccf.value_id = (cf.item ->> 'value')
WHERE cta.created_at >= '{{ start_date }}'::TIMESTAMP
  AND (
        ((cf.item ->> 'id')::INT = 9791 AND cta.brand_id = 1) OR 
        ((cf.item ->> 'id')::INT = 5868 AND cta.brand_id = 3) OR 
        ((cf.item ->> 'id')::INT = 5982 AND cta.brand_id = 4)
  )
ORDER BY cta.ticket_id, cta.updated_at DESC
