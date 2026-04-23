select 
	payment_date,
clineid,
payment,
brand_etl,
ma_phieu,
product_id,
crm_id,
---clineid,
company_id,
id
from  {{ source('raw_data', 'stag_payment_transfer') }} spt
where payment_date >= '2025-01-01'
----join  (select * from {{ ref('dps_cline') }} where number_used = 0) cl
---where number_used = 0