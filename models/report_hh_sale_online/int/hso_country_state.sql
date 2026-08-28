select
        id,
        brand_etl,
        name tinh
from {{source('hh','res_country_state')}}
where brand_etl =4
