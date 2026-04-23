select 
	id, 
	crm_id,
	brand_etl, 
	consultants_1, 
	product_id, 
	total,
	total_received,
	create_date, 
	stage, 
	number_used 
from  {{ source('raw_data', 'crm_line') }} 
---where number_used = 0