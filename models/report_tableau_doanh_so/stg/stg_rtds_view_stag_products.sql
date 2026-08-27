select * from {{ source('rtds_source', 'view_stag_products') }}
