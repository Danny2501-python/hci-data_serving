-- Tương đương query_emp trong quentk_1_stag_crm_New_sys.py.
-- KHÔNG join res_users/res_partner như bản gốc: 2 join đó không SELECT cột nào ra (dead join thuần
-- tuý trong code Python) và join key (id, đã xác nhận duy nhất theo (id, brand_etl)) không thể fan-out,
-- nên bỏ đi không đổi kết quả.
with he as (
    select * from {{ ref('stg_stem_hr_employee') }} where brand_etl = 7
),

-- Bảng map phòng ban "cũ" (theo department_id) sang tên phòng ban chuẩn hoá (new_name)
spi as (
    select * from {{ ref('stg_stem_stag_phongbanphanquyen_id') }}
),

-- Phòng ban chuẩn hoá brand_etl in (0,7), lấy id lớn nhất nếu trùng tên
hdc as (
    select max(id) as id, name
    from {{ ref('stg_stem_hr_department') }}
    where brand_etl in (0, 7)
    group by name
),

hd as (
    select * from {{ ref('stg_stem_hr_department') }} where brand_etl = 7
),

-- Nhân viên cùng employee_code ở brand kn/pr/hh (lấy id, user_id nhỏ nhất nếu trùng employee_code)
hekn as (
    select min(id) as id, min(user_id) as user_id, employee_code
    from {{ ref('stg_stem_hr_employee') }}
    where brand_etl = 1
    group by employee_code
),
hepr as (
    select min(id) as id, min(user_id) as user_id, employee_code
    from {{ ref('stg_stem_hr_employee') }}
    where brand_etl = 3
    group by employee_code
),
hehh as (
    select min(id) as id, min(user_id) as user_id, employee_code
    from {{ ref('stg_stem_hr_employee') }}
    where brand_etl = 4
    group by employee_code
),
hethv as (
    select min(id) as id, min(user_id) as user_id, employee_code
    from {{ ref('stg_stem_hr_employee') }}
    where brand_etl = 8
    group by employee_code
)

select
    he.id, he.user_id, he.employee_code, he.name as employee, he.gender,
    he.job_id, hj.name as job, he.group_job as group_job_id, hgj.name as group_job, hd.name as department,
    he.team_id, ht.name as team, he.sector_id, hds.name as sector,
    coalesce(hdc.id, he.department_id) as department_id, he.department_id as old_department_id, he.company_id,
    he.staff_level, he.area, he.birthday, he.place_of_birth, he.identification_id, he.barcode, he.mobile_phone, he.work_email,
    he.create_date + interval '7 hours' as create_date,
    he.write_date + interval '7 hours' as write_date,
    he.active, he.resign_date, he.reason_resign,
    rc.name as company, he.brand_id,
    hekn.id as kn_id, hekn.user_id as kn_user_id,
    hepr.id as pr_id, hepr.user_id as pr_user_id,
    hehh.id as hh_id, hehh.user_id as hh_user_id,
    hethv.id as thv_id, hethv.user_id as thv_user_id
from he
inner join {{ ref('stg_stem_m_res_company') }} rc on he.company_id = rc.id and rc.brand_etl = he.brand_etl
inner join {{ ref('stg_stem_res_brand') }} rb on rc.brand_id = rb.id and rb.brand_etl = rc.brand_etl
left join {{ ref('stg_stem_hr_department_sector') }} hds on he.sector_id = hds.id and he.brand_etl = hds.brand_etl
left join {{ ref('stg_stem_hr_team') }} ht on he.team_id = ht.id and ht.brand_etl = he.brand_etl
left join {{ ref('stg_stem_hr_job') }} hj on he.job_id = hj.id and he.brand_etl = hj.brand_etl
left join {{ ref('stg_stem_hr_group_job') }} hgj on he.group_job = hgj.id and he.brand_etl = hgj.brand_etl
left join spi on he.department_id = spi.department_id
left join hdc on spi.new_name = hdc.name
left join hd on coalesce(hdc.id, he.department_id) = hd.id
left join hekn on he.employee_code = hekn.employee_code
left join hepr on he.employee_code = hepr.employee_code
left join hehh on he.employee_code = hehh.employee_code
left join hethv on he.employee_code = hethv.employee_code
where rc.brand_etl = 7 and rb.brand_etl = 7
