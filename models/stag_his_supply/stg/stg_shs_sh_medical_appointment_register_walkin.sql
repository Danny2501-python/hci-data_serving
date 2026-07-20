select * from {{ source('shs_his', 'sh_medical_appointment_register_walkin') }}
