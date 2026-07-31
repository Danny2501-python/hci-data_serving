select *
from {{ source('idvs_erp', 'service_departments_rel') }}
