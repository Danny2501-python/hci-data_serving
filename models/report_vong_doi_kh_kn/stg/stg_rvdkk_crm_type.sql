select * from {{ source('rvdkk_source', 'crm_type') }} where brand_etl = 1
