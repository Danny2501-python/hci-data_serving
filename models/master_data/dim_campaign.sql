{{ config(materialized='table') }}

with source as (
    select distinct 
        ad_campaign_id as campaign_id,
        ad_campaign_name as campaign_name
    from {{ source('public', 'cs_facebook_insight') }}
    where ad_campaign_id is not null
)

select 
    md5(campaign_id) as id,
    campaign_id,
    campaign_name
from source
