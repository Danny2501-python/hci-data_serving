{{ config(materialized='table') }}

with inbox as (
    select *
    from {{ source('public', 'm_inbox_kangnam') }}
),
region_mapping as (
    -- Group by region to avoid duplicates in case dim_region has multiple entries for a single region
    select 
        region,
        max(country) as country
    from {{ ref('dim_region') }}
    where region is not null
    group by region
)

select 
    i.*,
    r.country
from inbox i
left join region_mapping r
    on i."vùng" = r.region
