with se as (
    select
        se.employee,
        se.work_email,
        se.user_id,
        se.brand_etl,
        row_number() over (
            partition by se.user_id
            order by case when se.brand_etl = 4 then 0 else 1 end
        ) as rnk
    from {{source('hh','view_stag_employees_user')}} se
    where brand_id = 4
)
select employee, work_email, user_id, brand_etl
from se
where rnk = 1
/*
select se.name employee,
        se.work_email,
        se.user_id,
        se.brand_etl
from {{source('hh','hr_employee')}} se where brand_etl =4*/


/*select   se.employee,
        se.work_email,
        se.user_id,
        se.brand_etl
from {{source('hh','view_stag_employees_user')}} se
where brand_id =4*/