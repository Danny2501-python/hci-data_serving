-- Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py, biến `se`
-- (dòng 347-384): danh mục nhân viên rút gọn, đã đổi tên cột, dùng để join theo Tư vấn viên/
-- Hỗ trợ/Người tạo booking. `stag_employees.employee` được title-case TRƯỚC khi tạo `se` trong bản
-- gốc (dòng 349, áp cho CẢ bảng `stag_employees` — nhưng chỉ `se` dùng cột `employee` nên port
-- ngay tại đây, không cần model riêng cho `stag_employees` đã title-case).
-- ⚠ `initcap()` (Postgres) và `.str.title()` (Python) không đảm bảo giống hệt 100% ở mọi trường hợp
-- biên (dấu nháy đơn, gạch nối trong tên) — chưa verify đối chiếu, cần kiểm tra nếu thấy tên nhân
-- viên hiển thị sai định dạng.

{{ config(materialized='ephemeral') }}

select
    kn_user_id,
    pr_user_id,
    hh_user_id,
    -- thv_user_id: bản gốc dùng dict_brand_etl[7]='sci' để ghép cột 'sci_user_id' — cột này KHÔNG
    -- tồn tại trong stag_employees (chỉ có kn/pr/hh/thv_user_id) — brand_etl=7 trong thực tế không
    -- xuất hiện trong report_kpi_bonus_commission (đã verify), nên đây là edge-case vô hại của bản
    -- gốc, không port cột "sci_user_id" ảo — xem int_rkbc_step1_commission.sql xử lý brand 7 = NULL.
    employee_code,
    initcap(employee) as employee,
    job_id,
    job,
    job_lv2,
    team_id,
    team,
    group_job_id,
    group_job,
    old_department_id as department_id,
    department,
    company as company_employee,
    company_id as employee_company_id,
    brand_id as employee_brand_id
from {{ ref('stg_rkbc_stag_employees') }}
