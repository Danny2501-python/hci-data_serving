{{ config(materialized='table') }}

with emp_base as (
    select 
        he.id, 
        he.user_id, 
        he.employee_code, 
        he.name as employee, 
        he.gender,
        he.job_id, 
        hj.name as job, 
        he.group_job as group_job_id, 
        hgj.name as group_job, 
        hd.name as department,
        he.team_id, 
        ht.name as team, 
        he.sector_id, 
        hds.name as sector,
        he.department_id as old_department_id, 
        he.company_id,
        he.staff_level, 
        he.area, 
        he.birthday, 
        he.place_of_birth, 
        he.identification_id, 
        he.barcode, 
        he.mobile_phone, 
        he.work_email,
        he.create_date + interval '7 hours' as create_date,
        he.write_date + interval '7 hours' as write_date,
        he.active, 
        he.resign_date, 
        he.reason_resign,
        rc.name as company, 
        he.brand_id, 
        rb.name as brand,
        he.brand_etl
    from {{ source('erp', 'hr_employee') }} he
    left join {{ source('erp', 'm_res_company') }} rc on he.company_id = rc.id and rc.brand_etl = he.brand_etl
    left join {{ source('erp', 'res_brand') }} rb on rc.brand_id = rb.id and rb.brand_etl = rc.brand_etl
    left join {{ source('erp', 'hr_department_sector') }} hds on he.sector_id = hds.id and he.brand_etl = hds.brand_etl
    left join {{ source('erp', 'hr_team') }} ht on he.team_id = ht.id and ht.brand_etl = he.brand_etl
    left join {{ source('erp', 'hr_job') }} hj on he.job_id = hj.id and he.brand_etl = hj.brand_etl
    left join {{ source('erp', 'hr_group_job') }} hgj on he.group_job = hgj.id and he.brand_etl = hgj.brand_etl
    left join {{ source('erp', 'hr_department') }} hd on he.department_id = hd.id and hd.brand_etl = he.brand_etl
    where he.brand_etl = 7
),

final as (
    select
        *,
        -- Logic Job LV2 (Phân loại Bác sĩ)
        case 
            when id in (2479, 2349, 2350, 2981, 2982, 2420, 2446, 2463, 2825, 2342) then 'Bác sĩ Tiểu phẫu chính'
            when id in (2464, 2365, 2983) then 'Bác sĩ Đại phẫu chính'
            when id in (2532) then 'Bác sĩ Tiểu phẫu thực hành'
            when id in (2558, 4146, 4268) then 'Bác sĩ Đại phẫu thực hành'
            when id in (2442, 2549, 2554) then 'Bác sĩ Phẫu thuật Hàm mặt'
            else job
        end as job_lv2,

        -- Logic Phòng ban phân quyền
        case 
            when old_department_id in (2635) or id = 3337 or (company_id = 4 and old_department_id = 2599)
            then 2602 
            else old_department_id 
        end as phongbanphanquyen
    from emp_base
)

select * from final
