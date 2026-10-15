{{ config(alias='stag_employees') }}

-- Tương đương write_stag_employees() trong quentk_1_stag_crm_New_sys.py.
-- Alias 'stag_employees_dbt' để không ghi đè bảng stag_employees đang chạy Python cho tới khi được
-- đối chiếu/duyệt (xem models/erp_staging/products/LOGIC.md, mục Cutover, cho quy trình chung).
--
-- UNION ALL với seed import_stag_employee_null: write_stag_employees() chỉ DELETE FROM stag_employees
-- WHERE id > 0 mỗi lần chạy -> các dòng id <= 0 (nhân sự "ảo"/thiếu data ERP, tài khoản hệ thống...)
-- KHÔNG BAO GIỜ được ghi lại bởi get_data_employee(), chỉ tồn tại nhờ 1 lần import thủ công trước đây.
-- Seed hiện khớp 100% (0 lệch id cả 2 chiều) với tập id<=0 của bảng stag_employees thật tại thời điểm
-- đối chiếu -- xem knowledge.md.
with processed as (
    select * from {{ ref('int_stem_processed') }}
),

legacy_seeded as (
    select * from {{ ref('import_stag_employee_null') }}
)

select
    id,
    nullif(employee_code, '') as employee_code,
    nullif(employee, '') as employee,
    nullif(gender, '') as gender,
    nullif(job, '') as job,
    nullif(department, '') as department,
    nullif(company, '') as company,
    nullif(staff_level, '') as staff_level,
    nullif(area, '') as area,
    birthday,
    nullif(place_of_birth, '') as place_of_birth,
    nullif(identification_id, '') as identification_id,
    nullif(barcode, '') as barcode,
    nullif(mobile_phone, '') as mobile_phone,
    nullif(work_email, '') as work_email,
    create_date,
    write_date,
    active,
    resign_date,
    nullif(reason_resign, '') as reason_resign,
    nullif(job_lv2, '') as job_lv2,
    group_job_id,
    nullif(group_job, '') as group_job,
    team_id,
    nullif(team, '') as team,
    sector_id,
    nullif(sector, '') as sector,
    user_id,
    job_id,
    department_id,
    company_id,
    brand_id,
    old_department_id,
    phongbanphanquyen,
    kn_id,
    kn_user_id,
    pr_id,
    pr_user_id,
    hh_id,
    hh_user_id,
    thv_id,
    thv_user_id,
    da_id,
    da_user_id
from processed

union all

select
    id,
    nullif(employee_code, '') as employee_code,
    nullif(employee, '') as employee,
    nullif(gender, '') as gender,
    nullif(job, '') as job,
    nullif(department, '') as department,
    nullif(company, '') as company,
    nullif(staff_level, '') as staff_level,
    nullif(area, '') as area,
    birthday,
    nullif(place_of_birth, '') as place_of_birth,
    nullif(identification_id, '') as identification_id,
    nullif(barcode, '') as barcode,
    nullif(mobile_phone, '') as mobile_phone,
    nullif(work_email, '') as work_email,
    create_date,
    write_date,
    active,
    resign_date,
    nullif(reason_resign, '') as reason_resign,
    nullif(job_lv2, '') as job_lv2,
    group_job_id,
    nullif(group_job, '') as group_job,
    team_id,
    nullif(team, '') as team,
    sector_id,
    nullif(sector, '') as sector,
    user_id,
    job_id,
    department_id,
    company_id,
    brand_id,
    old_department_id,
    phongbanphanquyen,
    kn_id,
    kn_user_id,
    pr_id,
    pr_user_id,
    hh_id,
    hh_user_id,
    -- Seed import_stag_employee_null (import CSV thủ công cũ) không có cột thv_id/thv_user_id (được thêm
    -- vào bảng thật sau này) -- toàn bộ 316 dòng id<=0 của bảng thật đều NULL ở 2 cột này, cast NULL literal
    -- để khớp.
    cast(null as int) as thv_id,
    cast(null as int) as thv_user_id,
    cast(null as int) as da_id,
    cast(null as int) as da_user_id
from legacy_seeded
