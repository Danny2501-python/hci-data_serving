select * from {{ source('rtqdp_source', 'crm_type') }}
