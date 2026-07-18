select id, requester_id
from {{source('data','cs_deal_detail_api_v2')}}
where brand_id =1