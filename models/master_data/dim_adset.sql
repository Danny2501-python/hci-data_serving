{{ config(materialized='table') }}

with source as (
    select 
        adset_id,
        adset_name,
        row_number() over (partition by adset_id order by "date" desc) as rn
    from {{ source('public', 'cs_facebook_insight') }}
    where adset_id is not null
)

select 
    md5(adset_id) as id,
    adset_id,
    adset_name
from source
where rn = 1
