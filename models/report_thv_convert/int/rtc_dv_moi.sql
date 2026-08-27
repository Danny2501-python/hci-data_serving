select
    ticket_id,
    nhom_dv
from {{ ref('rtc_v_dv_moi') }}
