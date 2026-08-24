--- chuyển từ view_cs_new_customer (bản Kangnam)
--- cs_ticket_api_thv/cs_contact_api_thv chỉ chứa dữ liệu THV nên không cần filter brand_id
--- ngày tạo khách ưu tiên lấy từ cs_contact_api_thv; nếu không có (bảng này thiếu dữ liệu nặng ở
--- giai đoạn 2026-01..2026-04, chỉ khớp được 5-11% ticket) thì lấy ngày tạo ticket nhỏ nhất của khách hàng đó

select distinct on (cta.requester_id)
    cta.ticket_id,
    cta.custom_fields,
    cta.requester_id,
    cta.ticket_source,
    coalesce(cca.created_at, min(cta.created_at) over (partition by cta.requester_id)) as ngay_tao_khach
from {{ source('rtc_base', 'cs_ticket_api_thv') }} cta
left join {{ source('rtc_base', 'cs_contact_api_thv') }} cca on cca.id = cta.requester_id
order by cta.requester_id, cta.created_at
