--- khách hàng mới

select
    ngay_tao_khach,
    ticket_id,
    ticket_source,
    requester_id::text as requester_id
from {{ ref('rtc_v_new_customer') }}
