select * from {{ source('rkbc_source', 'view_stag_products') }}
