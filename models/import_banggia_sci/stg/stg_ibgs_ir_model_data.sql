select *
from {{ source('ibgs_erp', 'ir_model_data') }}
