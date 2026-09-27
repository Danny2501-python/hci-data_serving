select * from {{ source('rtds_source', 'ggs_target_company_source') }}
