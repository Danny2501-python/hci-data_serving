select * from {{ source('rvdkk_source', 'res_users') }} where brand_etl = 1
