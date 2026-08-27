select
    created_at,
    ticket_id,
    ticket_source,
    requester_id::text as requester_id
from {{ ref('rtc_v_inbox_all') }}
