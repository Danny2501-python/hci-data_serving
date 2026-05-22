select id,
        name,
        brand_etl
from {{source('kso_crm_base','')}}
where brand_etl =1

