{{ config(materialized='table') }}

with source as (
    select 
        facebook_page_id as page_id,
        page_name,
        ad_id,
        ad_name,
        row_number() over (partition by facebook_page_id, ad_id order by "date" desc) as rn
    from {{ source('public', 'cs_facebook_insight') }}
    where facebook_page_id is not null and ad_id is not null
)

select 
    md5(coalesce(page_id, '') || '_' || coalesce(ad_id, '')) as id,
    page_id,
    page_name,
    ad_id,
    ad_name
from source
where rn = 1
