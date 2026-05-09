select * from {{ source('rtqdp_source', 'stag_payment_transfer') }}
