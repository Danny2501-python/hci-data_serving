select * 
from {{source('data','m_res_company')}} 
where brand_etl =1