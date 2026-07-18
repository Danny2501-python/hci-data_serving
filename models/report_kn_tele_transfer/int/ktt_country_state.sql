select
        id,
        brand_etl,
        name tinh
from {{source('data','res_country_state')}}
where brand_etl =1
