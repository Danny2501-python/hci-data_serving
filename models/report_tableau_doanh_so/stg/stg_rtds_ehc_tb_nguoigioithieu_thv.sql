select * from {{ source('rtds_source', 'ehc_tb_nguoigioithieu_thv') }}
