select *
from {{ source('idvs_erp', 'sh_medical_labtest_types') }}
