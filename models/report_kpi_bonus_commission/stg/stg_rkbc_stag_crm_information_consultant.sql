select * from {{ source('rkbc_source', 'stag_crm_information_consultant') }}
