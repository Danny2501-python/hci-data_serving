select * from {{ source('rvdkk_source', 'stag_payment_transfer') }} where brand_etl = 1
