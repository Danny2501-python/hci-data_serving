select *
from {{ source('idvs_erp', 'service_rooms_rel') }}
