select * from {{ source('rtqdp_source', 'stag_products') }}
