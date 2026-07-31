select *
from {{ source('idvs_erp', 'sh_medical_services_labtest_types_rel') }}
