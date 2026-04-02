with mfpk as (
    select
        csa.service_type,
        csa.service_id,
        coalesce(
            nullif(split_part(csa.detail, '"', 4), ''),
            nullif(split_part(csa.detail, '''', 4), '')
        ) as page_id,
        csa.service_name,
        coalesce(
            substring(csa.detail from '"created_at"\s*:\s*"([^"]+)"'),
            substring(csa.detail from '''created_at''\s*:\s*''([^'']+)''')
        ) as created_at
    from {{ source('ads_raw_data', 'cs_services_api') }} csa
    where csa.detail is not null and csa.brand_id = 1 and csa.service_type = 'Inbox Facebook'::text
)

select * from mfpk


