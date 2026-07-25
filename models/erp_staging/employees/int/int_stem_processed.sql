-- Tương đương phần xử lý sau query_emp trong get_data_employee() (v2):
-- phongbanphanquyen (gán tạm phân quyền phòng ban), backfill user_id/id brand kn/pr/hh/thv cho tài khoản
-- admin/hệ thống (user_id nhỏ hoặc null) -- v2: for b in list(dict_brand_etl.values())[1:-1] giờ chạy qua
-- 4 brand (kn/pr/hh/thv) thay vì 3 (kn/pr/hh) vì dict_brand_etl có thêm thv, map job_lv2 (dùng seed
-- import_stag_employee_doctor thay vì hard-code lại dict_job/dict_emp), và dedup theo employee_code.
with base as (
    select * from {{ ref('int_stem_base') }}
),

flagged as (
    select
        base.*,
        -- company_id=4 & department_id=2599: xử lý tạm phân quyền phòng ban BS Đoàn Hùng Thịnh
        -- (BV KNSG - Chuyên khoa PTTM)
        case
            when coalesce(department_id, 0) = 2635
                or id = 3337
                or (coalesce(company_id, 0) = 4 and coalesce(department_id, 0) = 2599)
            then 2602
            else department_id
        end as phongbanphanquyen,
        -- Tài khoản admin/hệ thống (user_id null hoặc < 10): nếu chưa map được sang brand kn/pr/hh
        -- qua employee_code thì backfill bằng chính id/user_id của dòng brand sci này.
        coalesce(user_id, 0) < 10 as is_user_admin
    from base
),

job_lv2_map as (
    select id as employee_id, job_name as job_lv2
    from {{ ref('import_stag_employee_doctor') }}
),

with_job_lv2 as (
    select
        flagged.*,
        coalesce(job_lv2_map.job_lv2, flagged.job) as job_lv2,
        case when flagged.kn_user_id is null and flagged.is_user_admin then flagged.user_id else flagged.kn_user_id end as kn_user_id_final,
        case when flagged.kn_id is null and flagged.is_user_admin then flagged.id else flagged.kn_id end as kn_id_final,
        case when flagged.pr_user_id is null and flagged.is_user_admin then flagged.user_id else flagged.pr_user_id end as pr_user_id_final,
        case when flagged.pr_id is null and flagged.is_user_admin then flagged.id else flagged.pr_id end as pr_id_final,
        case when flagged.hh_user_id is null and flagged.is_user_admin then flagged.user_id else flagged.hh_user_id end as hh_user_id_final,
        case when flagged.hh_id is null and flagged.is_user_admin then flagged.id else flagged.hh_id end as hh_id_final,
        case when flagged.thv_user_id is null and flagged.is_user_admin then flagged.user_id else flagged.thv_user_id end as thv_user_id_final,
        case when flagged.thv_id is null and flagged.is_user_admin then flagged.id else flagged.thv_id end as thv_id_final
    from flagged
    left join job_lv2_map on job_lv2_map.employee_id = flagged.id
),

deduped as (
    select
        *,
        row_number() over (partition by employee_code order by active asc, create_date asc) as rn
    from with_job_lv2
)

select
    id, user_id, employee_code, employee, gender,
    job_id, job, group_job_id, group_job, department,
    team_id, team, sector_id, sector,
    department_id, old_department_id, company_id,
    staff_level, area, birthday, place_of_birth, identification_id, barcode, mobile_phone, work_email,
    create_date, write_date,
    active, resign_date, reason_resign,
    company, brand_id,
    job_lv2, phongbanphanquyen,
    kn_id_final as kn_id, kn_user_id_final as kn_user_id,
    pr_id_final as pr_id, pr_user_id_final as pr_user_id,
    hh_id_final as hh_id, hh_user_id_final as hh_user_id,
    thv_id_final as thv_id, thv_user_id_final as thv_user_id
from deduped
where rn = 1
