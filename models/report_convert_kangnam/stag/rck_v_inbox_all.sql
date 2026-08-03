--- chuyển từ view public.view_cs_inbox_all

select distinct on (cta.ticket_id)
    cta.ticket_id,
    cta.custom_fields,
    cta.requester_id,
    cta.ticket_source,
    cta.created_at,
    cf.chi_nhanh
from {{ source('rck_base', 'cs_ticket_api') }} cta
left join lateral (
    select x.value ->> 'value' as chi_nhanh
    from jsonb_array_elements(cta.custom_fields::jsonb) x(value)
    where (x.value ->> 'id')::integer = 9799
) cf on true
where cta.brand_id = 1
and cta.created_at >= '2024-06-01 00:00:00'::timestamp
order by cta.ticket_id, cta.created_at
