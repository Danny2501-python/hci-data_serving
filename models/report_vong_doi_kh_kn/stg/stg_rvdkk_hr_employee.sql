select * from {{ source('rvdkk_source', 'hr_employee') }} where brand_etl = 1
