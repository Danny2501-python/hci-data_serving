select * from {{ source('tqds_crm_base', 'utm_campaign') }}
