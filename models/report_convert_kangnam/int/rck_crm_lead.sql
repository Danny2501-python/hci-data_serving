select
    id,
    ticket_id,
    phone,
    create_date + interval '7 hours' as create_date_new,
    stage_id,
    type_crm_id
from {{ source('rck_base', 'crm_lead') }}
where brand_etl = 1
and ticket_id <> 0
and ticket_id is not null
