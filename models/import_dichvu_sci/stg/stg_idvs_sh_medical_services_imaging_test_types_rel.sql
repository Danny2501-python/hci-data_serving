select *
from {{ source('idvs_erp', 'sh_medical_services_imaging_test_types_rel') }}
