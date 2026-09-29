select * from {{ source('rkbc_source', 'stag_sources') }}
