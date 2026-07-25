select *
from {{ source('stps_erp', 'uom_uom') }}
