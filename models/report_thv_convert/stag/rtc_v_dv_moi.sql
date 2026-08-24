--- chuyển từ view_cs_dv_moi (bản Kangnam), custom_field_id 10829 = "Nhóm dịch vụ" bên THV
--- value_lable của cs_custom_fields_thv không có định dạng "[...] " nên không cần split_part/trim như bản gốc

select distinct on (cta.ticket_id)
    cta.ticket_id,
    ccf.value_lable as nhom_dv,
    cta.brand_id,
    cta.ticket_source as source
from {{ source('rtc_base', 'cs_ticket_api_thv') }} cta
join lateral (
    select x.value ->> 'value' as value
    from jsonb_array_elements(cta.custom_fields::jsonb) x(value)
    where (x.value ->> 'id')::integer = 10829
) cf on true
left join {{ source('rtc_base', 'cs_custom_fields_thv') }} ccf on ccf.value_id = cf.value
where cta.created_at > '2024-05-01 00:00:00'::timestamp
and ccf.value_lable is not null
order by cta.ticket_id, cta.updated_at desc
