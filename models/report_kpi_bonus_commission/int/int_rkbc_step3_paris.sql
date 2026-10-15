-- Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py,
-- hàm `step3_transform_paris()` (dòng 717-820) — RIÊNG thương hiệu Paris (brand_id=3), dùng cơ chế
-- Tư vấn viên KHÁC hẳn Kangnam/Hồng Hà/brand7 (int_rkbc_step2_kangnam.sql): tra cứu Thành viên tư vấn
-- thật từ bảng `stag_crm_information_consultant` (bắc cầu theo crm_id+clineid, có thể FAN-OUT 1 dòng
-- thanh toán thành NHIỀU dòng — mỗi dòng 1 người tư vấn), fallback về Tư vấn 1/2 trên crm_line nếu
-- không có ai nhập trên CRM Paris.
--
-- ⚠ 3 điểm KHÔNG phải port cơ học — cần biết trước khi tin số liệu:
--   1. `col_common` (121 cột) tái dùng nguyên từ int_rkbc_step2_kangnam.sql — nghĩa là các cột TV1
--      "mồ côi" của bản gốc (`ext`, `rto_1`, `consulting_role_1`, và các cột employee_code/employee/
--      job/department/department_id/team_id/team/group_job_id/group_job/employee_company_id/
--      employee_brand_id/company_employee TRƯỚC KHI bị ghi đè bởi merge stag_employees.pr_user_id ở
--      dòng 782 gốc) KHÔNG được port — ĐÃ RÀ SOÁT: các cột này không được bản gốc dùng lại sau khi bị
--      ghi đè/bỏ qua, nên bỏ không ảnh hưởng kết quả, chỉ đơn giản hoá schema output.
--   2. `rn_id_clineid` (dòng 758 gốc): `groupby().cumcount()` phụ thuộc thứ tự dòng hiện tại (đã sort
--      theo [clineid, rn_consult] ở dòng 756) — port bằng `ROW_NUMBER() ... ORDER BY rn_consult` —
--      SUY ĐOÁN hợp lý (giống cảnh báo tương tự ở step1/step2), chưa verify khớp 100%.
--   3. `consults` (dòng 720-727 gốc): `DISTINCT ON (crm_id, crm_line_id, user_id, "role")` KHÔNG có
--      `ORDER BY` tường minh trong bản gốc (Postgres cho phép, chọn dòng bất kỳ trong mỗi nhóm) — giữ
--      nguyên không tự thêm ORDER BY, đúng hành vi gốc (kết quả có thể không ổn định giữa các lần
--      chạy nếu nhóm có >1 dòng trùng key, hiếm khi xảy ra vì key đã khá đặc thù).
{{ config(materialized='table') }}

with consults as (
    select distinct on (crm_id, crm_line_id, user_id, "role")
        id, crm_id, crm_line_id as clineid, user_id, "role", data_union,
        row_number() over (partition by crm_id, crm_line_id order by case when "role" = 'recept' then 1 else 99 end) as rn_cline_consult,
        row_number() over (partition by data_union, crm_line_id order by id) as rn_consult,
        count(id) over (partition by crm_id, crm_line_id, "role") as count_consult_in_role,
        count(id) over (partition by crm_id, crm_line_id) as count_consult_in_cline
    from {{ ref('stg_rkbc_stag_crm_information_consultant') }}
    where brand_etl = 3
),

-- src: df[brand_id==3] (dòng 730 gốc) — chỉ giữ "cột chung" (col_common, xem cảnh báo #1) + các cột
-- TV1/TV2 thô cần làm INPUT cho việc xác định người tư vấn thật (dòng 737-751 gốc).
src as (
    select
        id, ma_phieu, crm_id, payment_date, payment_method, clineid,
        product_id, quantity, uom_price, number_used, total, total_received,
        total_received_cumsum, total_received_recal, payment, payment_type, stage_product, price_list_id,
        orgcompany_id, company_id, communication, product_type, write_date, brand_id,
        brand_etl, first_date_payment, rnk_crm_pmdate, rnk_clineid_pmdate, rnk_clineid_pmdate_desc, is_bonus_commission,
        total_received_cumsum_lag1, crm_id_join, type_crm_id, booking, type_data_partner, code_customer,
        contact_name, arrival_date, create_by, partner_id, note, source_id,
        login, product_ctg_id, his_service_type, surgery_type, product_category, product,
        kpi_point, kpi_point_num, is_no_kpi, type_guarantee, discount_percent, discount_cash,
        other_discount, sale_to, discount_cs_percent, discount_cs_amount, total_discount_review, total_before_discount,
        total_discount, total_last, total_received_last, total_discount_percent, price_min, source_extend_id,
        extensive_source_classification, reason_line_cancel, category_source_id, category_source, source, source_extend,
        price_list, is_price_list_flexible_discount, total_price_min, is_bonus_commission_back, payment_date_complete_debt, org_brand_id,
        company, org_company, org_group_clineid, total_recept_sell, job_id, job_lv2,
        creator_employee_code, creator_employee, creator_department, is_recept_sell_org, ccjob, diff_day_payment,
        total_owed, is_received, is_owed, is_paid_unful, is_paid_ful, deposit_type,
        is_sell_recept, id1, id2, is_sell_dermatology, is_ccjob_dermatology_doctor, is_group_job_cssdv,
        is_ccjob_recept, rto_key, is_his_service, is_kpi_branch, pay_bonus, cdt1,
        cdt2, cdt3, commission_bonus_raw, commission_bonus_shift1, commission_bonus, d_mth,
        mth, week_in_mth, payment_kpi_accumulated_w1, payment_kpi_accumulated_w2, payment_kpi_accumulated_w3, payment_kpi_accumulated_w4,
        payment_kpi_accumulated_w, consultants_1, consultants_2, rto_1, rto_2,
        commission_department as commission_department_tv1_raw,
        commission_department_2 as commission_department_2_tv2_raw
    from {{ ref('int_rkbc_step1_commission') }}
    where coalesce(brand_id, 0) = 3
),

-- Dòng 734 gốc — JOIN theo (crm_id, clineid) CHỦ ĐÍCH FAN-OUT: 1 dòng thanh toán → N dòng (N = số
-- người tư vấn tìm được trên CRM Paris cho booking/dịch vụ đó).
joined as (
    select
        s.*,
        c.data_union, c.user_id, c."role", c.rn_consult, c.count_consult_in_role, c.count_consult_in_cline
    from src s
    left join consults c on c.crm_id = s.crm_id and c.clineid = s.clineid
),

-- Dòng 744-751 gốc: xác định người tư vấn (Nhân viên CRM Paris nếu có, else fallback TV1 crm_line)
-- + tỷ lệ chia doanh số cá nhân.
branch_a as (
    select
        j.*,
        (case when j.user_id is null then 'consult_1' else j."role" end) as ordinal_consult,
        coalesce(case when j.user_id is null then j.consultants_1 else j.user_id end, 0) as consultants,
        coalesce(
            case
                when j.data_union = 'cosmetic' and j.rn_consult = 1 then 1.0
                when j.product_category <> 'SAN PHAM' then 1.0 / nullif(j.count_consult_in_role, 0)
            end,
            j.rto_1
        ) as rto,
        j.commission_department_tv1_raw as commission_department_pre
    from joined j
),

-- Dòng 737-742 gốc: dòng BỔ SUNG cho Tư vấn 2 (chỉ khi CRM Paris không có ai tư vấn nhưng crm_line có
-- Tư vấn 2).
branch_b as (
    select
        j.*,
        'consult_2' as ordinal_consult,
        coalesce(j.consultants_2, 0) as consultants,
        j.rto_2 as rto,
        j.commission_department_2_tv2_raw as commission_department_pre
    from joined j
    where j.user_id is null and coalesce(j.consultants_2, 0) <> 0
),

dfcpr_union as (
    select * from branch_a
    union all
    select * from branch_b
),

-- Dòng 753-755 gốc.
dfcpr_calc as (
    select
        u.*,
        (u.payment * u.rto) as commission_employee,
        u."role" as consulting_role
    from dfcpr_union u
),

-- Dòng 756-759 gốc.
dfcpr_ord as (
    select
        c.*,
        bool_or(c.consulting_role = 'recept') over (partition by c.clineid) as is_exists_consult,
        row_number() over (partition by c.id, c.clineid, c.product_id order by c.rn_consult) as rn_id_clineid,
        count(*) over (partition by c.id, c.clineid, c.product_id) as rn_id_clineid_max
    from dfcpr_calc c
),

-- Dòng 780-788 gốc: GHI ĐÈ toàn bộ thông tin nhân viên bằng lookup thật theo `consultants` (id CRM
-- Paris đã xác định ở trên) → `stag_employees.pr_user_id` — KHÔNG dùng lại thông tin TV1/TV2 cũ nữa
-- (xem cảnh báo #1 đầu file).
dfcpr_emp as (
    select
        o.*,
        se.old_department_id as department_id,
        se.company_id as employee_company_id,
        se.brand_id as employee_brand_id,
        se.employee_code,
        initcap(se.employee) as employee,
        se.job,
        se.department,
        se.group_job_id,
        se.group_job,
        se.team_id,
        se.team,
        se.company as company_employee,
        se.phongbanphanquyen
    from dfcpr_ord o
    left join {{ ref('stg_rkbc_stag_employees') }} se on se.pr_user_id = o.consultants
),

-- Dòng 805 gốc.
dfcpr_pbpq as (
    select
        e.*,
        p.department_id as department_id_pbpq
    from dfcpr_emp e
    left join {{ ref('int_rkbc_pbpq_getone') }} p on p.company_id = e.company_id and p.brand_etl = e.brand_etl
),

-- Dòng 792-795 gốc — phân loại phòng ban theo nhóm chuyên môn (giống hệt dept_calc trong
-- int_rkbc_step1_commission.sql, chỉ 1 phiên bản vì Paris đã gộp về đúng 1 Tư vấn viên/dòng).
dfcpr_dept as (
    select
        p.*,
        case
            when coalesce(p.department_id, 0) in (2617,2601,2562,2553,2348,2315,2309,2301,2251,2215,2199,2198,2153,2141,2120,2108,2103,2084,2070,2066,2054,2053,2048,2046,2045)
                or coalesce(p.department, 'None') ~* 'thẩm mỹ da|laser|spa|vận hành dịch vụ' then 'Laser_Spa_Card'
            when coalesce(p.department_id, 0) in (2607,2605,2604,2603,2602,2599,2598,2047)
                or coalesce(p.department, 'None') ~* 'phẫu thu|gây mê|thay b|dịch vụ khách|quan h|chuyên môn|đại phẫu|tiểu phẫu|điều dưỡng' then 'Surgery'
            when coalesce(p.department_id, 0) in (2600,2547,2373,2327,2304,2254,2219,2208,2202,2182,2169,2161,2151,2135,2117,2113,2109,2100,2092,2089,2079,2072,2062)
                or coalesce(p.department, 'None') ~* 'nha|răng' then 'Odontology'
            else p.department
        end as dept
    from dfcpr_pbpq p
)

select
    d.*,
    -- Dòng 798-800 gốc.
    case
        when (not (coalesce(d.dept, 'None') ~* 'surgery|laser|spa|odo|card')) or (not (coalesce(d.his_service_type, 'None') ~* 'surgery|laser|spa|odo|card')) then ''
        when not (coalesce(d.dept, 'None') ~* coalesce(d.his_service_type, 'None')) then 'ext02'
        else 'ext01'
    end as extensive_cross_upsell,
    -- Dòng 806-808 gốc.
    (case
        when coalesce(d.employee_company_id, 0) = d.company_id and coalesce(d.department_id, 0) <> 0 then d.phongbanphanquyen
        when d.employee_company_id is distinct from d.company_id then d.department_id_pbpq
        else d.department_id
    end) as phongbanphanquyen_fix,
    -- Dòng 809-811 gốc.
    d.company_id as chinhanhphanquyen_fix,
    d.brand_id as thuonghieuphanquyen_fix,
    0 as nr_clone_permission,
    -- Dòng 766-776 gốc.
    (case
        when d.rn_id_clineid_max = 1 then d.payment
        when d.data_union = 'cosmetic' then d.commission_employee
        when d.ordinal_consult like 'consult%' then d.commission_department_pre
        when d.rn_id_clineid = 1 and not coalesce(d.is_exists_consult, false) then d.payment
        when coalesce(d.consulting_role, '') = 'recept' then d.payment * d.rto
        else null
    end) as commission_department,
    -- Dòng 777-778 gốc.
    (d.commission_bonus / nullif(d.count_consult_in_cline, 0)) as commission_bonus_employee,
    (d.commission_bonus / nullif(d.count_consult_in_cline, 0)) as commission_bonus_department
from dfcpr_dept d
