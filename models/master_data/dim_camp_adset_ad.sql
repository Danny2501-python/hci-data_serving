{{ config(materialized='table') }}

with source as (
    select 
        ad_account_id as account_id,
        ad_id,
        adset_id,
        ad_campaign_id,
        row_number() over (partition by ad_id,adset_id,ad_campaign_id order by "date" desc) as rn
    from {{ source('public', 'cs_facebook_insight') }}
    where ad_id is not null
)

select 
    md5(coalesce(account_id, '') || '_' || coalesce(ad_campaign_id, '') || '_' || coalesce(adset_id, '') || '_' || coalesce(ad_id, '')) as id,
    account_id,
    ad_campaign_id,
    adset_id,
    ad_id
from source
where rn = 1
