select * from {{ source('shs_his', 'stock_picking') }}
