select *
from {{source('hh','m_res_company')}}
where brand_etl =4