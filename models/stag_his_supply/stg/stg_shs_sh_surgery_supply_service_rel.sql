select * from {{ source('shs_his', 'sh_surgery_supply_service_rel') }}
