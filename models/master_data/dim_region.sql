{{ config(materialized='table') }}

with source as (
    select distinct 
        country,
        region
    from {{ source('public', 'cs_facebook_insight') }}
    where country is not null or region is not null
)

select 
    md5(coalesce(country, '') || '_' || coalesce(region, '')) as id,
    country,
    region
from source
