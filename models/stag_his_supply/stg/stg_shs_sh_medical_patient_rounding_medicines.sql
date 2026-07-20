select * from {{ source('shs_his', 'sh_medical_patient_rounding_medicines') }}
