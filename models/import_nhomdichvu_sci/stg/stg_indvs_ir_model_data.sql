select *
from {{ source('indvs_erp', 'ir_model_data') }}
