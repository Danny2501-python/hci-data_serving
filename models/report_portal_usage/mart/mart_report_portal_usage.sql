with pgsuvip as (
    select * from {{ ref('stg_portal_guide_statistic_user_views_in_portal') }}
),

pgcpr as (
    select * from {{ ref('stg_portal_guide_core_portal_report') }}
),

pgcrt as (
    select * from {{ ref('stg_portal_guide_core_report_type') }}
),

pgce as (
    select * from {{ ref('int_portal_usage__employees') }}
),

sss as (
    select * from {{ ref('int_portal_usage__reports') }}
)

select
	pgsuvip.*,
	pgcpr."name" as name_report,
	pgcpr.is_kpi,
	pgcrt."name" as report_type,
	initcap(pgce.user_name) as user_name,
	pgce.email,
	pgce.department,
	pgce.job,
	pgce.company,
	pgce.brand,
	pgce.sector,
	pgce.work_email,
	sss.url,
	sss.folder_report,
	sss.is_active
from
	pgsuvip
left join pgcpr on
	pgsuvip.portal_report_id = pgcpr.id
left join pgcrt on 
	pgcrt.id = pgcpr.report_type_id
left join pgce on
	pgce.id = pgsuvip.employee_id
left join sss on 
    sss.id = pgsuvip.portal_report_id
where 
    pgcpr."name" is not null 
    and pgce.user_name not ilike '%test%'
