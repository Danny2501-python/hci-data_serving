select *
from {{ source('idvs_erp', 'uom_uom') }}
