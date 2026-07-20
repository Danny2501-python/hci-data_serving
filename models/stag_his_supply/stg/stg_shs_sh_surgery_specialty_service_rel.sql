select * from {{ source('shs_his', 'sh_surgery_specialty_service_rel') }}
