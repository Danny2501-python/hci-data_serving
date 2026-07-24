select *
from {{ source('stps_erp', 'sh_medical_health_center_service_category') }}
