select *
from {{ source('idvs_erp', 'exam_rooms_rel') }}
