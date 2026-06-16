{{ config(materialized='table') }}

with source as (
    select 
        ad_account_id as account_id,
        ad_account_name as account_name,
        row_number() over (partition by ad_account_id order by "date" desc) as rn
    from {{ source('public', 'cs_facebook_insight') }}
    where ad_account_id is not null
)

select 
    md5(account_id) as id,
    account_id,
    account_name
from source
where rn = 1
