select *
from {{ source('indvs_erp', 'sh_medical_health_center_service_category') }}
