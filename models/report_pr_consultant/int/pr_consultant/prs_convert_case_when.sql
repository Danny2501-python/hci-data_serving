select 	*
from {{source('prs_raw_data', 'dm_convert_case_when')}} dccw 
where  table_name = 'crm_lead' and brand_etl = 3