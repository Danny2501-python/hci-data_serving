{{ config(materialized='table') }}

with source as (
    select distinct 
        facebook_page_id as page_id,
        page_name
    from {{ source('public', 'cs_facebook_insight') }}
    where facebook_page_id is not null
)

select 
    md5(page_id) as id,
    page_id,
    page_name
from source
