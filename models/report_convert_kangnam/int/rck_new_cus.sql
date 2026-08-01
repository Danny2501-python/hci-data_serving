--- khách hàng mới

select
    ngay_tao_khach,
    ticket_id,
    ticket_source,
    requester_id::text as requester_id,
    chi_nhanh
from {{ ref('rck_v_new_customer') }}
