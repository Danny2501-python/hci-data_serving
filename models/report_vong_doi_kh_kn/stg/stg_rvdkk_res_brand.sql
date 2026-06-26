select * from {{ source('rvdkk_source', 'res_brand') }} where brand_etl = 1
