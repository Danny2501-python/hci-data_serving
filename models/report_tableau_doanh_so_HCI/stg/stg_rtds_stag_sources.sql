select * from {{ source('rtds_source', 'stag_sources') }}
