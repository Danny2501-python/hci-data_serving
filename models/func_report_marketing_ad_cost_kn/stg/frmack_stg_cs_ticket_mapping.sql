with a as (
    select
        cta.ticket_id,
        cta.service_id
    from {{ source('ads_raw_data', 'cs_ticket_api') }} cta
    where
        cta.updated_at >= '2025-01-01 00:00:00'::timestamp
        and cta.brand_id = 1
        and (cta.ticket_source = any (array['Inbox Facebook'::text, 'Inbox Facebook Out'::text]))
),

b as (
    select
        a.*,
        row_number() over (partition by a.ticket_id order by a.ticket_id) as rnk
    from a
)

select
    b.ticket_id,
    b.service_id
from b
where b.rnk = 1
