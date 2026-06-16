{{ config(materialized='table') }}

with source as (
    select distinct 
        adset_id,
        adset_name
    from {{ source('public', 'cs_facebook_insight') }}
    where adset_id is not null
)

select 
    md5(adset_id) as id,
    adset_id,
    adset_name
from source
