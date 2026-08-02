--- map ticket_id -> tên page facebook (qua cs_chat_api + dim_page)
--- distinct on (ticket_id): 1 ticket có thể match nhiều facebook_page_id/page_name, chỉ giữ 1 dòng đại diện để tránh nhân bản khi join

select distinct on (ticket_id)
    ticket_id,
    facebook_page_id,
    page_name
from (
    select
        cca.ticket_id,
        cca.facebook_page_id,
        dp.page_name
    from {{ source('rck_base', 'cs_chat_api') }} cca
    left join {{ source('rck_base', 'dim_page') }} dp on trim(dp.page_id::text) = trim(cca.facebook_page_id)
    where cca.brand_id = 1
    and cca.start_time >= '2025-01-01'
) t
order by ticket_id, facebook_page_id
