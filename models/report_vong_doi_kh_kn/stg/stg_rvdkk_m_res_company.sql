select * from {{ source('rvdkk_source', 'm_res_company') }} where brand_etl = 1
