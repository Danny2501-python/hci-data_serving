select * from {{ source('rvdkk_source', 'stag_sources') }} where brand_id = 1
