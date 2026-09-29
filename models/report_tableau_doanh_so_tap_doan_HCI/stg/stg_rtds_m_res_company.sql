select * from {{ source('rtds_source', 'm_res_company') }}
