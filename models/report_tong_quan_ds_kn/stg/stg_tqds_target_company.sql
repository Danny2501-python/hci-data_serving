select * from {{ source('tqds_crm_base', 'ggs_target_company') }}
