select * from {{ source('rvdkk_source', 'crm_category_source') }} where brand_etl = 1
