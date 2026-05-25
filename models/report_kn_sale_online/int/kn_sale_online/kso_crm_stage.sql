select id,
        name as trang_thai, 
        brand_etl 
from {{source('kso_crm_base','crm_stage')}} ecs
where brand_etl =1