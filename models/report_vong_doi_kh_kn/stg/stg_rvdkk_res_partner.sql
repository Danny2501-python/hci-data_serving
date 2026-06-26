select * from {{ source('rvdkk_source', 'res_partner') }} where brand_etl = 1
