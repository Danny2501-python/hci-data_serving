select * from {{ source('rkbc_source', 'stag_employees') }}
