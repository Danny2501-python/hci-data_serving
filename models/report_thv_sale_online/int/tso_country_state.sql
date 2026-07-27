select
        id,
        brand_etl,
        name tinh
from {{source('thv','res_country_state')}}
where brand_etl =8
