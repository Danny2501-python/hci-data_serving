{{ config(materialized='table') }}

with source as (
    select 
        ad_id,
        ad_name,
        row_number() over (partition by ad_id order by "date" desc) as rn
    from {{ source('public', 'cs_facebook_insight') }}
    where ad_id is not null
)

select 
    md5(ad_id) as id,
    ad_id,
    ad_name
from source
where rn = 1
