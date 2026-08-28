-- Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py,
-- hàm `step2_transform_kangnam()` (dòng 620-707) — MẶC DÙ TÊN HÀM GHI "kangnam", điều kiện lọc thật
-- sự là `brand_id != 3` (KHÔNG PHẢI brand_etl) → áp dụng cho MỌI thương hiệu TRỪ Paris (Kangnam,
-- Hồng Hà, brand 7...) — Paris dùng cơ chế tư vấn viên khác, xử lý riêng ở int_rkbc_step3_paris.sql.
--
-- Ý tưởng cốt lõi: "UNPIVOT" mỗi dòng thanh toán (đã có sẵn cột Tư vấn 1 + Tư vấn 2 + Hỗ trợ tư vấn
-- nằm ngang từ int_rkbc_step1_commission) thành TỐI ĐA 3 dòng dọc (1 dòng/vai trò tư vấn), sau đó xử
-- lý "phân quyền" (chi nhánh/phòng ban/thương hiệu nào được TÍNH doanh số cho dòng đó) — kể cả nhân
-- bản (clone) dòng khi Nhân viên tư vấn công tác ở Chi nhánh KHÁC Chi nhánh ghi nhận doanh số.
--
-- ⚠ 4 điểm KHÔNG phải port cơ học — cần biết trước khi tin số liệu:
--   1. `commission_employee/_bonus_employee/_department/_bonus_department` được đặt tên `..._raw`
--      xuyên suốt các CTE bên dưới (khác tên cột cuối cùng) — CHỦ ĐÍCH kỹ thuật để tránh phải liệt kê
--      lại ~140 cột (Postgres không có `SELECT * EXCLUDE(...)`), giá trị cuối (có thể bị null hoá khi
--      `nr_clone_permission=1`) chỉ tính ở SELECT ngoài cùng — KHÔNG phải sai lệch logic.
--   2. Dòng 659 gốc: join `consultants` (đã fillna(0) — port `coalesce(consultants,0)`) thẳng với
--      `stag_employees.kn_user_id` — KHÔNG lọc theo brand_etl/brand_id, dù step2 xử lý CẢ Kangnam LẪN
--      Hồng Hà/brand7 (kn_user_id vốn là id theo thang Kangnam). Với Hồng Hà/brand7,
--      `department_id_se`/`phongbanphanquyen` từ join này gần như luôn NULL (trừ trùng số ngẫu
--      nhiên) → `department_id_std_target`/`phongbanphanquyen_fix` fallback về giá trị khác — ĐÂY LÀ
--      HÀNH VI GỐC (có thể là hạn chế/sơ suất của bản gốc, không phải chủ đích rõ ràng), giữ nguyên
--      không tự "sửa" thêm điều kiện brand.
--   3. Dòng 657-658 gốc (`kpi_concat.merge(users[...], ...)` không gán lại biến) — DEAD CODE, không
--      có tác dụng gì trong bản gốc → KHÔNG port.
--   4. `rn_id_clineid` (dòng 699 gốc): `groupby().cumcount()` phụ thuộc thứ tự dòng hiện tại của
--      DataFrame (đã sort theo booking/clineid/ordinal_consult ở dòng 649, dòng nhân bản kpi3 luôn
--      nối SAU dòng gốc) — port bằng `ROW_NUMBER() ... ORDER BY ordinal_consult, (nr_clone_permission
--      = 2)` (dòng gốc trước, dòng nhân bản sau) — SUY ĐOÁN hợp lý, chưa verify khớp 100%.
{{ config(materialized='table') }}

with src as (
    select * from {{ ref('int_rkbc_step1_commission') }}
    where coalesce(brand_id, 0) <> 3
),

-- temp1/temp2/temp3 (dòng 636-644 gốc): 3 "vai trò" tư vấn — Tư vấn 1 (luôn giữ, kể cả không có
-- consultants), Tư vấn 2 (chỉ giữ nếu có), Hỗ trợ tư vấn (chỉ giữ nếu có `ho_tro`, KHÔNG có
-- ext/rto/commission_* — col_emp_sup gốc không gồm các cột này, giữ NULL đúng hành vi `pd.concat`).
temp1 as (
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
        payment_kpi_accumulated_w,
        ext, rto_1 as rto, consulting_role_1 as consulting_role, consultants,
        employee_code, employee, job, department, department_id, team_id, team, group_job_id, group_job,
        employee_company_id, employee_brand_id, company_employee,
        commission_employee as commission_employee_raw,
        commission_bonus_employee as commission_bonus_employee_raw,
        commission_department as commission_department_raw,
        commission_bonus_department as commission_bonus_department_raw,
        'consult_1' as ordinal_consult
    from src
),

temp2 as (
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
        payment_kpi_accumulated_w,
        ext_2 as ext, rto_2 as rto, consulting_role_2 as consulting_role, consultants_2_fix as consultants,
        employee_code_2 as employee_code, employee_2 as employee, job_2 as job, department_2 as department,
        department_id_2 as department_id, team_id_2 as team_id, team_2 as team, group_job_id_2 as group_job_id,
        group_job_2 as group_job, employee_company_id_2 as employee_company_id,
        employee_brand_id_2 as employee_brand_id, company_employee_2 as company_employee,
        commission_employee_2 as commission_employee_raw,
        commission_bonus_employee_2 as commission_bonus_employee_raw,
        commission_department_2 as commission_department_raw,
        commission_bonus_department_2 as commission_bonus_department_raw,
        'consult_2' as ordinal_consult
    from src
    where coalesce(consultants_2_fix, 0) > 0
),

temp3 as (
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
        payment_kpi_accumulated_w,
        null::text as ext, null::numeric as rto, '99' as consulting_role, ho_tro as consultants,
        employee_code_sup as employee_code, employee_sup as employee, job_sup as job, department_sup as department,
        department_id_sup as department_id, team_id_sup as team_id, team_sup as team, group_job_id_sup as group_job_id,
        group_job_sup as group_job, employee_company_id_sup as employee_company_id,
        employee_brand_id_sup as employee_brand_id, company_employee_sup as company_employee,
        null::numeric as commission_employee_raw,
        null::numeric as commission_bonus_employee_raw,
        null::numeric as commission_department_raw,
        null::numeric as commission_bonus_department_raw,
        'supporter' as ordinal_consult
    from src
    where coalesce(ho_tro, 0) > 0
),

kpi_concat as (
    select * from temp1
    union all
    select * from temp2
    union all
    select * from temp3
),

-- Dòng 659 gốc — xem cảnh báo #2 đầu file (join thẳng kn_user_id, không lọc brand).
kpi_se as (
    select
        k.*,
        se.department_id as department_id_se,
        se.phongbanphanquyen as phongbanphanquyen
    from kpi_concat k
    left join {{ ref('stg_rkbc_stag_employees') }} se on se.kn_user_id = coalesce(k.consultants, 0)
),

-- Dòng 661 gốc.
kpi_pbpq as (
    select
        k.*,
        p.department_id as department_id_pbpq
    from kpi_se k
    left join {{ ref('int_rkbc_pbpq_getone') }} p on p.company_id = k.company_id and p.brand_etl = k.brand_etl
),

-- Dòng 663-664 gốc: kiểm tra cặp (company_id, phongbanphanquyen nhân viên, brand_etl) có hợp lệ
-- trong hr_department_company không? (chỉ cần rn_dept_cpn để biết CÓ khớp hay không).
kpi_checkpq as (
    select
        k.*,
        h.rn_dept_cpn as rn_dept_cpn
    from kpi_pbpq k
    left join {{ ref('int_rkbc_hr_department_company') }} h
        on h.company_id = k.company_id and h.department_id = k.phongbanphanquyen and h.brand_etl = k.brand_etl
),

-- Dòng 667 gốc.
kpi_dstd as (
    select
        k.*,
        coalesce(k.department_id_se, k.department_id) as department_id_std_target
    from kpi_checkpq k
),

-- Dòng 674-682 gốc: điều kiện nhân bản (to_clone) — Nhân viên tư vấn công tác ở Chi nhánh KHÁC Chi
-- nhánh ghi nhận doanh số.
kpi_clone_flag as (
    select
        k.*,
        (
            coalesce(k.employee_company_id, 0) > 1
            and k.employee_company_id is distinct from k.company_id
            and coalesce(k.brand_id, 0) in (1,2,3,4)
            and coalesce(k.consultants, 0) not in (1,2,3,4,5,6284)
            and k.ordinal_consult <> 'supporter'
            and not (coalesce(k.employee_company_id, 0) = 4 and coalesce(k.company_id, 0) = 12)
        ) as to_clone
    from kpi_dstd k
),

-- Branch A = "kpi" gốc (dòng 666-672 gốc, TẤT CẢ các dòng, kể cả dòng sẽ bị nhân bản).
branch_a as (
    select
        k.*,
        (case when k.to_clone then 1 else 0 end) as nr_clone_permission,
        k.brand_id as thuonghieuphanquyen_fix,
        (case when k.company_id = 12 and k.payment_date >= '2026-08-01'::date then 4 else k.company_id end) as chinhanhphanquyen_fix,
        (case
            when coalesce(k.rn_dept_cpn, 0) = 0 and coalesce(k.department_id_pbpq, 0) <> 0 then k.department_id_pbpq
            when coalesce(k.phongbanphanquyen, 0) <> 0 then k.phongbanphanquyen
            else k.department_id
        end) as phongbanphanquyen_fix
    from kpi_clone_flag k
),

-- Branch B = "kpi3" (dòng 685-691 gốc, CHỈ dòng to_clone=true, join LẠI pbpq_getone theo company_id/
-- brand_etl GỐC (chưa đổi sang employee_company_id) — giữ đúng hành vi gốc dù có vẻ dư thừa so với
-- department_id_pbpq đã tính ở branch A cùng key).
branch_b as (
    select
        k.*,
        2 as nr_clone_permission,
        k.employee_brand_id as thuonghieuphanquyen_fix,
        k.employee_company_id as chinhanhphanquyen_fix,
        coalesce(k.phongbanphanquyen, p2.department_id) as phongbanphanquyen_fix
    from kpi_clone_flag k
    left join {{ ref('int_rkbc_pbpq_getone') }} p2 on p2.company_id = k.company_id and p2.brand_etl = k.brand_etl
    where k.to_clone
),

-- Dòng 698 gốc: nối kpi (branch A) + kpi3 (branch B).
kpi_trans as (
    select * from branch_a
    union all
    select * from branch_b
)

select
    t.*,
    -- Dòng 693-695 gốc: dòng gốc BỊ nhân bản (nr_clone_permission=1) mất doanh số cá nhân/phòng ban
    -- (đã ghi nhận ở dòng nhân bản/branch B thay), dòng nhân bản (=2) và dòng không nhân bản (=0) giữ
    -- nguyên giá trị.
    (case when t.nr_clone_permission = 1 then null else t.commission_employee_raw end) as commission_employee,
    (case when t.nr_clone_permission = 1 then null else t.commission_bonus_employee_raw end) as commission_bonus_employee,
    (case when t.nr_clone_permission = 1 then null else t.commission_department_raw end) as commission_department,
    (case when t.nr_clone_permission = 1 then null else t.commission_bonus_department_raw end) as commission_bonus_department,
    -- Dòng 699 gốc — xem cảnh báo #4 đầu file.
    row_number() over (
        partition by t.id, t.clineid, t.product_id
        order by t.ordinal_consult, (t.nr_clone_permission = 2)
    ) as rn_id_clineid
from kpi_trans t
