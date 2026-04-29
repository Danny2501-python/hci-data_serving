select user_id,
crm_line_id,
brand_etl
from {{ source('raw_data', 'crm_information_consultant') }} cic
where "role" = 'recept'