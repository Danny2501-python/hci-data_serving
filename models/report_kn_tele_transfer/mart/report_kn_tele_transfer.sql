
with a as (
select upper(first_user) user_report,
 * from {{ ref('ktt_combine') }}
where first_user = create_user
union all
select upper(first_user) user_report ,
 * from {{ ref('ktt_combine') }}
where create_user is null
union all
select upper(create_user) user_report,
 * from {{ ref('ktt_combine') }}
where first_user is null and create_user is not null
)
select 'data_report' as type_report,
*
from a
union all 
select 'data_expand_create' as type_report, ---lấy từ lead trở đi
    upper(create_user) user_report ,
 * from {{ ref('ktt_combine') }}
where first_user <> create_user
union all
select 'data_expand' as type_report, ---lấy từ lead trở đi
upper(first_user) user_report ,
 * from {{ ref('ktt_combine') }}
where first_user <> create_user