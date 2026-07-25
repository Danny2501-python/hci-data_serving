select *
from {{ source('stem_erp', 'stag_phongbanphanquyen_id') }}
