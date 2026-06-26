select * from {{ source('rvdkk_source', 'stag_sources') }} where brand_etl = 1
