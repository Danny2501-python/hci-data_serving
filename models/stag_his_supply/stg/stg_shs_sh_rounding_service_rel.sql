select * from {{ source('shs_his', 'sh_rounding_service_rel') }}
