select
    created_at,
    ticket_id,
    ticket_source,
    requester_id::text as requester_id,
    chi_nhanh
from {{ ref('rck_v_inbox_all') }}
