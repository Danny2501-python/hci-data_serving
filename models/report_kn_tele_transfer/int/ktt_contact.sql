select * 
from {{source('data','cs_contact_api')}}
where brand_id =1