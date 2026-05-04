with pgcpr as (
    select * from {{ ref('stg_rpu_portal_report') }}
),

pgcrf_source as (
    select * from {{ ref('stg_rpu_report_folder') }}
),

folder_hierarchy as (
    select
        pgcpr.id,
        concat('https://portal.scigroup.com.vn/Admin/Report/ViewReport?id=', pgcpr.id) as url,
        pgcpr.is_active,
        case 
            when pgcrf5."name" is not null then concat(pgcrf5."name", ' / ', pgcrf4."name",  ' / ', pgcrf3."name", ' / ', pgcrf2."name",  ' / ', pgcrf."name") 
            when pgcrf4."name" is not null and pgcrf5."name" is null then  concat(pgcrf4."name",  ' / ', pgcrf3."name", ' / ', pgcrf2."name",  ' / ', pgcrf."name")  
            when pgcrf3."name" is not null and pgcrf4."name" is null and pgcrf5."name" is null then concat(pgcrf3."name", ' / ', pgcrf2."name",  ' / ', pgcrf."name")  
            when pgcrf2."name" is not null and pgcrf3."name" is null and pgcrf4."name" is null and pgcrf5."name" is null then concat(pgcrf2."name",  ' / ', pgcrf."name")  
            when pgcrf."name" is not null and pgcrf2."name" is null and pgcrf3."name" is null and pgcrf4."name" is null and pgcrf5."name" is null then pgcrf."name"
        end as folder_report
    from
        pgcpr
    left join pgcrf_source pgcrf on
        pgcrf.id = pgcpr.report_folder_id
    left join pgcrf_source pgcrf2 on
        pgcrf.parent_id = pgcrf2.id
    left join pgcrf_source pgcrf3 on
        pgcrf2.parent_id = pgcrf3.id
    left join pgcrf_source pgcrf4 on
        pgcrf3.parent_id = pgcrf4.id
    left join pgcrf_source pgcrf5 on
        pgcrf4.parent_id = pgcrf5.id
)

select * from folder_hierarchy
