--- chuyển từ view public.view_cs_new_customer

select distinct on (cta.requester_id)
    cta.ticket_id,
    cta.custom_fields,
    cta.requester_id,
    cta.ticket_source,
    cca.created_at as ngay_tao_khach,
    cf.chi_nhanh
from {{ source('rck_base', 'cs_ticket_api') }} cta
left join {{ source('rck_base', 'cs_contact_api') }} cca on cca.id = cta.requester_id
left join lateral (
    select x.value ->> 'value' as chi_nhanh
    from jsonb_array_elements(cta.custom_fields::jsonb) x(value)
    where (x.value ->> 'id')::integer = 9799
) cf on true
where cta.brand_id = 1
and cta.created_at >= '2026-05-01'::timestamp
and cca.created_at >= '2024-06-01'::timestamp
order by cta.requester_id, cta.ticket_id
