select * from {{ source('rvdkk_source', 'crm_stage') }} where brand_etl = 1
