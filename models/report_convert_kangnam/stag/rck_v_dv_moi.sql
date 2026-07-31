--- chuyển từ view public.view_cs_dv_moi

select distinct on (cta.ticket_id)
    cta.ticket_id,
    trim(both from split_part(ccf.value_lable, ']', 2)) as nhom_dv,
    cta.brand_id,
    cta.ticket_source as source
from {{ source('rck_base', 'cs_ticket_api') }} cta
join lateral (
    select x.value ->> 'value' as value
    from jsonb_array_elements(cta.custom_fields::jsonb) x(value)
    where (x.value ->> 'id')::integer = 9794
) cf on true
left join {{ source('rck_base', 'cs_custom_fields') }} ccf on ccf.value_id = cf.value
where cta.created_at > '2024-05-01 00:00:00'::timestamp
and ccf.value_lable is not null
order by cta.ticket_id, cta.updated_at desc
