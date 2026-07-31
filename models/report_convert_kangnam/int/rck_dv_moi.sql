select
    ticket_id,
    nhom_dv
from {{ ref('rck_v_dv_moi') }}
