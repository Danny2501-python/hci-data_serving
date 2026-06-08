select * from {{ source('rtqdp_source', 'view_stag_products') }}
where brand_etl = 3