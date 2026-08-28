-- Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py, biến
-- `hr_department_company` (dòng 354-371, `query_department_id`) — bảng dự phòng id phongbanphanquyen
-- theo phòng Lễ tân/Kinh doanh dịch vụ/Nha khoa tại 1 Chi nhánh. Dùng chung bởi step2 (Kangnam/Hồng
-- Hà/brand7) và step3 (Paris) — bản gốc chỉ tính 1 lần ở top-level script.
-- Thuần SQL trong bản gốc, port cơ học 1:1.

{{ config(materialized='ephemeral') }}

with cte as (
    select
        dc.hr_department_id as department_id,
        dc.res_company_id as company_id,
        hd.name,
        hd.company_id as hd_company_id,
        dc.brand_etl,
        case
            when hd.name ilike '%kinh doanh dịch vụ%' then 1
            when hd.name ilike '%lễ tân%' then 2
            when hd.name ilike '%nha kh%' then 3
        end as ordinal_dept
    from {{ ref('stg_rkbc_hr_department_res_company_rel') }} dc
    left join {{ ref('stg_rkbc_hr_department') }} hd on dc.hr_department_id = hd.id and dc.brand_etl = hd.brand_etl
)
select
    cte.*,
    row_number() over (partition by cte.company_id order by cte.ordinal_dept) as rn_dept_cpn,
    row_number() over (partition by cte.company_id, cte.brand_etl order by cte.ordinal_dept) as rn_dept_cpn_br
from cte
