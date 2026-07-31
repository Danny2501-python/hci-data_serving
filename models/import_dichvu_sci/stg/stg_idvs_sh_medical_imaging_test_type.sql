select *
from {{ source('idvs_erp', 'sh_medical_imaging_test_type') }}
