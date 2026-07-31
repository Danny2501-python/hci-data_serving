select *
from {{ source('idvs_erp', 'ir_model_data') }}
