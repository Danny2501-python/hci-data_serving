--- chuyển từ view_cs_inbox_all (bản Kangnam)
--- cs_ticket_api_thv chỉ chứa dữ liệu THV nên không cần filter brand_id

select distinct on (cta.ticket_id)
    cta.ticket_id,
    cta.custom_fields,
    cta.requester_id,
    cta.ticket_source,
    cta.created_at
from {{ source('rtc_base', 'cs_ticket_api_thv') }} cta
where cta.created_at >= '2024-06-01 00:00:00'::timestamp
order by cta.ticket_id, cta.created_at
