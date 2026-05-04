with pgce as (
    select * from {{ ref('stg_rpu_core_employee') }}
),

se_source as (
    select * from {{ ref('stg_rpu_employees') }}
),

employee_matched as (
    select
        pgce.id,
        pgce.email,
        pgce.user_name,
        se.employee,
        se.employee_code,
        se.department,
        se.job,
        se.company,
        se.sector,
        case
            when se.brand_id = 1 then 'Kangnam'
            when se.brand_id = 2 then 'Đông Á'
            when se.brand_id = 3 then 'Paris'
            when se.brand_id = 4 then 'Hồng Hà'
            when se.brand_id = 5 then 'Học Viện SCIAcademy'
            when se.brand_id = 7 then 'SCI'
        end brand,
        se.work_email
    from
        pgce
    left join lateral (
        select * from se_source se
        where
            case
                when pgce.email ilike '%@nhakhoaparis%' then concat(split_part(pgce.email, '@nhakhoaparis', 1), '@nhakhoaparis.com.vn')
                when pgce.email ilike '%@scigroup%' then concat(split_part(pgce.email, '@scigroup', 1), '@scigroupvn.com') 
                when pgce.email ilike '%@kangnam%' then concat(split_part(pgce.email, '@kangnam', 1), '@kangnam.vn')
                when pgce.email ilike '%@benhvienhongha%' then concat(split_part(pgce.email, '@benhvienhongha', 1), '@benhvienhongha.com.vn')
                when pgce.email ilike '%@dongabeauty%' then concat(split_part(pgce.email, '@dongabeauty', 1), '@dongabeauty.vn')
                else pgce.email
            end  =      
            case
                when se.work_email ilike '%@nhakhoaparis%' then concat(split_part(se.work_email, '@nhakhoaparis', 1), '@nhakhoaparis.com.vn')
                when se.work_email ilike '%@scigroup%' then concat(split_part(se.work_email, '@scigroup', 1), '@scigroupvn.com') 
                when se.work_email ilike '%@kangnam%' then concat(split_part(se.work_email, '@kangnam', 1), '@kangnam.vn')
                when se.work_email ilike '%@benhvienhongha%' then concat(split_part(se.work_email, '@benhvienhongha', 1), '@benhvienhongha.com.vn')
                when se.work_email ilike '%@dongabeauty%' then concat(split_part(se.work_email, '@dongabeauty', 1), '@dongabeauty.vn')
                else se.work_email
            end
        order by write_date desc 
        limit 1
    ) se on true
)

select * from employee_matched
