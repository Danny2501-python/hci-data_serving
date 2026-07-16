select * from {{ source('shs_his', 'sh_medical_evaluation') }}
