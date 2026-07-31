select *
from {{ source('idvs_erp', 'sh_medical_health_center_ot') }}
