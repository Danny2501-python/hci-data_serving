select * from {{ source('rkbc_source', 'crm_line') }}
