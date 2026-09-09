-- Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py,
-- hàm `step_report_kpi_commission_transpose()` (dòng 850-877) — ghép Doanh số/Thưởng
-- Kangnam+Hồng Hà+brand7 (int_rkbc_step2_kangnam) với Paris (int_rkbc_step3_paris) thành 1 bảng đã
-- "unpivot" theo Tư vấn viên (1 dòng = 1 Payment x 1 vai trò tư vấn).
--
-- ⚠ KHÁC BIỆT CHỦ ĐÍCH so với bản gốc (xem đầy đủ lý do ở report_kpi_bonus_commission.sql, áp dụng
-- tương tự cho bảng này — DB khác staging_sci, test unique/not_null thay vì âm thầm bỏ qua batch,
-- incremental+pre_hook thay vì mất lịch sử):
--   Riêng thêm 1 điểm CHỈ CÓ ở bảng này — chọn "danh sách cột public": bản gốc lấy `existing_columns`
--   của bảng Postgres CÓ SẴN (dòng 857-858: `SELECT * FROM {table_trans} LIMIT 0`) rồi cắt CẢ 2
--   DataFrame Kangnam/Paris về đúng danh sách đó trước khi `pd.concat` — cơ chế này VỪA để 2
--   DataFrame có cùng schema (bắt buộc để concat) VỪA để khớp bảng đích có sẵn. Vì là bảng MỚI, không
--   có "existing_columns" để tham chiếu — TỰ CHỌN danh sách cột "public" bên dưới: toàn bộ cột raw cấp
--   Payment (giống hệt int_rkbc_step1_commission) + các cột "theo Tư vấn viên" đã cùng tên ở CẢ 2 model
--   nguồn (commission_employee, commission_department, phongbanphanquyen_fix, v.v...). KHÔNG giữ các
--   cột nội bộ chỉ có ở 1 bên (vd `to_clone`, `rn_dept_cpn`, `department_id_se` chỉ ở step2;
--   `data_union`, `user_id`, `role`, `dept`, `is_exists_consult` chỉ ở step3) — các cột này chỉ phục vụ
--   tính toán trung gian trong bản gốc, không nằm trong output cuối cùng của DataFrame `df` gốc dùng
--   để tính các cột trên (chúng bị "che" bởi bước lọc existing_columns ở bản gốc, không phải cố ý loại
--   trừ khỏi logic — chỉ là không public ra bảng báo cáo).
--
-- ⚠ CHƯA chạy thử qua `dbt run`/`dbt test` thật (chỉ soát tay so với int_rkbc_step2_kangnam.sql /
-- int_rkbc_step3_paris.sql, đối chiếu tên+ý nghĩa cột, KHÔNG verify được kiểu dữ liệu 2 bên UNION ALL
-- có tương thích 100% không) — cần chạy thật để bắt lỗi kiểu dữ liệu/tên cột nếu có trước khi tin số
-- liệu.
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    post_hook="{{ rkbc_update_info(this) }}",
    pre_hook="{% if is_incremental() %}delete from {{ this }} where brand_etl > 0 and payment_date >= (select greatest(date_trunc('month', current_date - interval '15 days')::date, '{{ var(\"rkbc_floor_date\", \"2026-08-01\") }}'::date)){% endif %}"
) }}

with kangnam as (
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
        ordinal_consult, consultants, extensive_cross_upsell, rto, consulting_role,
        employee_code, employee, job, department, department_id, team_id, team, group_job_id, group_job,
        employee_company_id, employee_brand_id, company_employee,
        commission_employee, commission_bonus_employee, commission_department, commission_bonus_department,
        phongbanphanquyen_fix, chinhanhphanquyen_fix, thuonghieuphanquyen_fix, nr_clone_permission, rn_id_clineid
    from {{ ref('int_rkbc_step2_kangnam') }}
),

paris as (
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
        ordinal_consult, consultants, extensive_cross_upsell, rto, consulting_role,
        employee_code, employee, job, department, department_id, team_id, team, group_job_id, group_job,
        employee_company_id, employee_brand_id, company_employee,
        commission_employee, commission_bonus_employee, commission_department, commission_bonus_department,
        phongbanphanquyen_fix, chinhanhphanquyen_fix, thuonghieuphanquyen_fix, nr_clone_permission, rn_id_clineid
    from {{ ref('int_rkbc_step3_paris') }}
),

combined as (
    select * from kangnam
    union all
    select * from paris
)

-- id_etl (dòng 862-864 gốc): concat_str([id, clineid, product_id, consultants, ordinal_consult,
-- chinhanhphanquyen_fix].fillna(0), sep='-') — NULL ở BẤT KỲ cột nào trong 6 cột khoá đều thành
-- literal '0' (giống Python `fillna(0)` áp cho CẢ 6 cột rồi mới nối chuỗi), KHÔNG phải chuỗi rỗng.
select
    c.*,
    coalesce(c.id::text, '0') || '-' || coalesce(c.clineid::text, '0') || '-' || coalesce(c.product_id::text, '0')
        || '-' || coalesce(c.consultants::text, '0') || '-' || coalesce(c.ordinal_consult, '0')
        || '-' || coalesce(c.chinhanhphanquyen_fix::text, '0') as id_etl
from combined c
