select * from {{ source('rvdkk_source', 'hr_department') }} where brand_etl = 1
