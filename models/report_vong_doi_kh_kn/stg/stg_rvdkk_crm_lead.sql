select * from {{ source('rvdkk_source', 'crm_lead') }} where brand_etl = 1
