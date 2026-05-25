select id,
        name,
        brand_etl
from {{source('kso_crm_base','m_res_company')}}
where brand_etl =1

