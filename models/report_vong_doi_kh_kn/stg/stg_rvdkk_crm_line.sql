select * from {{ source('rvdkk_source', 'crm_line') }} where brand_etl = 1
