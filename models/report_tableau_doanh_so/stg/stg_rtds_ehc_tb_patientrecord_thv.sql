select * from {{ source('rtds_source', 'ehc_tb_patientrecord_thv') }}
