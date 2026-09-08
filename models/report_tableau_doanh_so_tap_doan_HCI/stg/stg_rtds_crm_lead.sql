select * from {{ source('rtds_source', 'crm_lead') }}
