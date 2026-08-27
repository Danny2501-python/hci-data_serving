select * from {{ source('rtds_source', 'crm_line_product') }}
