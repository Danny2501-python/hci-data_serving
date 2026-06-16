{{ config(materialized='table') }}

with source as (
    select distinct 
        ad_id,
        ad_name
    from {{ source('public', 'cs_facebook_insight') }}
    where ad_id is not null
)

select 
    md5(ad_id) as id,
    ad_id,
    ad_name
from source
