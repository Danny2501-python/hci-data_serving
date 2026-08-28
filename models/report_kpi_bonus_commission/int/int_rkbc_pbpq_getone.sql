-- Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py, biến `pbpq_getone`
-- (dòng 374): mỗi (company_id, brand_etl) lấy đúng 1 id phongbanphanquyen đại diện (rn_dept_cpn_br=1
-- và có tên phòng ban) — dùng để dự phòng khi nhân viên không có department_id tương ứng chi nhánh
-- được tính doanh số. Dùng chung bởi step2 và step3.

{{ config(materialized='ephemeral') }}

select department_id, company_id, name, hd_company_id, brand_etl
from {{ ref('int_rkbc_hr_department_company') }}
where rn_dept_cpn_br = 1 and name is not null
