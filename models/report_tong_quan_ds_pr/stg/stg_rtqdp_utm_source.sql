select * from {{ source('rtqdp_source', 'utm_source') }}
