-- Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py,
-- hàm `step1_transform_commission()` (dòng 416-611) — phần PHỨC TẠP NHẤT của cả pipeline (phân
-- loại bán chéo/mở rộng, tỷ lệ chia hoa hồng 8 trường hợp, thưởng chênh lệch, luỹ kế KPI tuần).
-- Đặt tên CTE theo ĐÚNG tên biến pandas gốc để đối chiếu dòng-đối-dòng khi cần.
--
-- ⚠ 3 điểm KHÔNG phải "port cơ học" — cần biết trước khi tin số liệu:
--   1. `commission_bonus_shift1` (dòng 577 gốc): pandas `.shift(1)` theo groupby KHÔNG có
--      `.sort_values()` tường minh trước đó trong step1 — thứ tự dòng phụ thuộc thứ tự SQL trả về
--      + cách nối 4 nhóm brand (không xác định 100%). Bản port này tự chọn
--      `ORDER BY payment_date, ma_phieu` (giống hệt pattern `total_received_cumsum_lag1` đã có sẵn
--      trong int_rkbc_base_payment.sql cho 1 phép LAG tương tự) — ĐÂY LÀ SUY ĐOÁN, chưa verify khớp
--      100% với thứ tự pandas thật, cần đối chiếu số liệu trước khi tin dùng.
--   2. `str(None)` khi nối chuỗi (concat_str, dòng 444-445 gốc: ccjob/ccdept nối job+job_2): Python
--      nối NULL thành literal "None" (4 ký tự) chứ không phải rỗng — dùng
--      `coalesce(x::text, 'None')` để khớp, KHÔNG dùng `coalesce(x,'')` (sẽ ra kết quả khác khi
--      chỉ 1 vế NULL và regex có thể match nhầm/không match đúng như bản gốc).
--   3. `payment_kpi_accumulated_w4` (dòng 599-602 gốc): dùng điều kiện `ngày <= 7*4 = 28`, KHÔNG
--      phải "cả tháng" — các ngày 29-31 CŨNG bị loại khỏi w4 (có vẻ là sơ suất từ bản gốc, không
--      phải chủ đích rõ ràng — vẫn giữ đúng hành vi gốc, không tự "sửa" thành <=31).

-- (2026-08-27) Đã THỬ dùng temp table thật qua pre_hook cho base_payment nhưng gặp lỗi dbt: nhiều
-- lệnh ref() trong khối Jinja set-block dùng làm chuỗi pre_hook bị resolve SAI (nhầm thành chính
-- bảng model hiện tại `int_rkbc_step1_commission`) — không an toàn cho pipeline tính hoa hồng, đã
-- BỎ hướng đó. `int_rkbc_base_payment` quay lại là model dbt riêng, `materialized='table'` (không
-- phải ephemeral/temp) — vẫn tránh được CTE chồng CTE quá sâu như mục tiêu ban đầu, chỉ khác là
-- persist giữa các lần `dbt run` thay vì biến mất ngay sau khi chạy.
{{ config(materialized='table') }}

with limit_date as (
    select greatest(
        date_trunc('month', current_date - interval '15 days')::date,
        '{{ var("rkbc_floor_date", "2026-08-01") }}'::date
    ) as ld
),

-- dfcd (dòng 419-420 gốc): lọc payment_date >= datetrunc (LỌC LẠI Ở MỨC DÒNG, khác với
-- limit_crm_id trong base_payment chỉ lọc ở mức booking) + loại 1 dòng lỗi biết trước
-- ('ti-165729-1') + bắt buộc có source_id.
dfcd as (
    select bp.*
    from {{ ref('int_rkbc_base_payment') }} bp
    where bp.payment_date >= (select ld from limit_date)
      and bp.id <> 'ti-165729-1'
      and bp.source_id is not null
),

-- Join nhân viên theo brand (dòng 401-440 gốc): dict_brand_etl = {1:'kn', 3:'pr', 4:'hh', 7:'sci'}
-- — brand 7 tra cột 'sci_user_id' KHÔNG tồn tại trong stag_employees (chỉ có thv_user_id) → luôn
-- NULL, brand 0/khác cũng NULL (dict_brand_etl[0]='' → cột rỗng không tồn tại, tương đương NULL) —
-- xem chú thích int_rkbc_se.sql. 4 nhóm join riêng (Tư vấn 1, Tư vấn 2, Hỗ trợ, Người tạo).
dfc as (
    select
        dfcd.*,

        -- Tư vấn 1 (suffix rỗng — dòng 430 dict_se['consultants']='')
        se1.employee_code as employee_code, se1.employee as employee, se1.job_id as job_id, se1.job as job,
        se1.job_lv2 as job_lv2, se1.team_id as team_id, se1.team as team, se1.group_job_id as group_job_id,
        se1.group_job as group_job, se1.department_id as department_id, se1.department as department,
        se1.company_employee as company_employee, se1.employee_company_id as employee_company_id,
        se1.employee_brand_id as employee_brand_id,

        -- Tư vấn 2 (suffix '_2', join theo consultants_2_fix)
        se2.employee_code as employee_code_2, se2.employee as employee_2, se2.job_id as job_id_2, se2.job as job_2,
        se2.job_lv2 as job_lv2_2, se2.team_id as team_id_2, se2.team as team_2, se2.group_job_id as group_job_id_2,
        se2.group_job as group_job_2, se2.department_id as department_id_2, se2.department as department_2,
        se2.company_employee as company_employee_2, se2.employee_company_id as employee_company_id_2,
        se2.employee_brand_id as employee_brand_id_2,

        -- Hỗ trợ tư vấn (suffix '_sup', join theo ho_tro)
        sesup.employee_code as employee_code_sup, sesup.employee as employee_sup, sesup.job_id as job_id_sup,
        sesup.job as job_sup, sesup.job_lv2 as job_lv2_sup, sesup.team_id as team_id_sup, sesup.team as team_sup,
        sesup.group_job_id as group_job_id_sup, sesup.group_job as group_job_sup,
        sesup.department_id as department_id_sup, sesup.department as department_sup,
        sesup.company_employee as company_employee_sup, sesup.employee_company_id as employee_company_id_sup,
        sesup.employee_brand_id as employee_brand_id_sup,

        -- Người tạo booking (suffix 'creator' → đổi tên 'creator_' + tên cột, dòng 440 gốc)
        secr.employee_code as creator_employee_code, secr.employee as creator_employee,
        secr.department as creator_department

    from dfcd
    left join {{ ref('int_rkbc_se') }} se1
        on (dfcd.brand_etl = 1 and dfcd.consultants = se1.kn_user_id)
        or (dfcd.brand_etl = 3 and dfcd.consultants = se1.pr_user_id)
        or (dfcd.brand_etl = 4 and dfcd.consultants = se1.hh_user_id)
    left join {{ ref('int_rkbc_se') }} se2
        on (dfcd.brand_etl = 1 and dfcd.consultants_2_fix = se2.kn_user_id)
        or (dfcd.brand_etl = 3 and dfcd.consultants_2_fix = se2.pr_user_id)
        or (dfcd.brand_etl = 4 and dfcd.consultants_2_fix = se2.hh_user_id)
    left join {{ ref('int_rkbc_se') }} sesup
        on (dfcd.brand_etl = 1 and dfcd.ho_tro = sesup.kn_user_id)
        or (dfcd.brand_etl = 3 and dfcd.ho_tro = sesup.pr_user_id)
        or (dfcd.brand_etl = 4 and dfcd.ho_tro = sesup.hh_user_id)
    left join {{ ref('int_rkbc_se') }} secr
        on (dfcd.brand_etl = 1 and dfcd.create_by = secr.kn_user_id)
        or (dfcd.brand_etl = 3 and dfcd.create_by = secr.pr_user_id)
        or (dfcd.brand_etl = 4 and dfcd.create_by = secr.hh_user_id)
),

-- Cờ/chuỗi cơ bản (dòng 441-460 gốc)
flags1 as (
    select
        dfc.*,
        (
            (coalesce(department, 'None') ~* 'lễ tân|kinh doanh dịch vụ' and coalesce(job, 'None') !~* 'chuyên viên')
            or (coalesce(department_2, 'None') ~* 'lễ tân|kinh doanh dịch vụ' and coalesce(job_2, 'None') !~* 'chuyên viên')
        ) as is_recept_sell_org,
        coalesce(job, 'None') || coalesce(job_2, 'None') as ccjob,
        coalesce(department, 'None') || coalesce(department_2, 'None') as ccdept,
        -- payment_date/first_date_payment đều kiểu `date` — trừ 2 date ra thẳng số nguyên ngày
        -- trong Postgres (khác timestamp phải qua extract(epoch)/86400), khớp đúng ý nghĩa
        -- `/np.timedelta64(1,'D')` bản gốc (dòng 449).
        (payment_date - first_date_payment) as diff_day_payment,
        (total::float8 - total_received_recal::float8) as total_owed
    from dfc
),

flags2 as (
    select
        f1.*,
        (coalesce(total_received_recal, 0) > 0) as is_received,
        (
            (coalesce(total_received_recal, 0) > 0)
            and (
                (coalesce(total_owed, 0) > 10)
                and (stage_product = 'done' or (coalesce(total_received_recal, 0) > 0))
            )
        ) as is_owed,
        (
            (coalesce(total_received_recal, 0) > 0)
            and coalesce(number_used, 0) = 0
        ) as is_paid_unful,
        (
            (coalesce(total_received_recal, 0) > 0)
            and total_owed = 0
        ) as is_paid_ful
    from flags1 f1
),

-- deposit_type (dòng 458-460 gốc) — np.select thứ tự ưu tiên: cancel > sell_cosmetic > owed >
-- paid_unfulfilled > full_payment > wrong_transfer > default 'unpaid'
deposit as (
    select
        f2.*,
        case
            when stage_product = 'cancel' then 'cancel'
            when product_category = 'SAN PHAM' then 'sell_cosmetic'
            when is_owed then 'owed'
            when is_paid_unful then 'paid_unfulfilled'
            when is_paid_ful then 'full_payment'
            when coalesce(total_received_recal, 0) < 0 then 'wrong_transfer'
            else 'unpaid'
        end as deposit_type
    from flags2 f2
),

-- Nhóm cờ xác định Lễ tân/Chuyên viên tư vấn cùng bán DV Phẫu thuật/Laser/Spa/Chi phí (dòng 462-494 gốc)
-- (tách flags3 thành 2 lớp vì Postgres không cho tham chiếu alias cùng cấp SELECT — id1/id2 phải
-- tính xong ở 1 CTE riêng trước khi is_ccjob_recept dùng lại được)
flags3a as (
    select
        d.*,
        (coalesce(his_service_type, 'None') ~* '(surgery|laser|spa|chiphi|card)') as is_sell_recept,
        (
            coalesce(ccjob, 'None') ~* 'lễ tân|chuyên viên tư v|kinh doanh dịch vụ'
            or coalesce(ccdept, 'None') ~* 'lễ tân|chuyên viên tư v|kinh doanh dịch vụ'
            or coalesce(department_id, 0) = 2612
            or coalesce(department_id_2, 0) = 2612
        ) as is_dept_recept,
        -- id1/id2 (dòng 474-476 gốc): user_id=6596 (Phan Yến Nhi) ưu tiên, else job_id
        (case when coalesce(consultants, 0) = 6596 then consultants else job_id end) as id1,
        (case when coalesce(consultants_2, 0) = 6596 then consultants_2 else job_id_2 end) as id2,
        (
            coalesce(his_service_type, 'None') ~* 'laser|spa|card'
            or product_category = 'SAN PHAM'
        ) as is_sell_dermatology,
        (
            coalesce(department_id, 0) in (2617,2601,2562,2553,2348,2315,2309,2301,2251,2215,2199,2198,2153,2141,2120,2108,2103,2084,2070,2066,2054,2053,2048,2046,2045)
            or coalesce(department, 'None') ~* 'thẩm mỹ da|laser|spa|vận hành dịch vụ'
        ) and (
            coalesce(department_id_2, 0) in (2617,2601,2562,2553,2348,2315,2309,2301,2251,2215,2199,2198,2153,2141,2120,2108,2103,2084,2070,2066,2054,2053,2048,2046,2045)
            or coalesce(department_2, 'None') ~* 'thẩm mỹ da|laser|spa|vận hành dịch vụ'
        ) as is_dept_dermatology,
        (
            (coalesce(job, 'None') || coalesce(job_2, 'None')) ~* '(bác sĩ|phòng|giám|trưởng).*(lase|spa|thẩm mỹ da|da liễu)'
            or coalesce(consultants, 0) = 1231
            or coalesce(consultants_2, 0) = 1231
        ) as is_ccjob_dermatology_doctor,
        (coalesce(group_job_id, 0) = 601 or coalesce(group_job_id_2, 0) = 601) as is_group_job_cssdv
    from deposit d
),

flags3 as (
    select
        f3a.*,
        (
            (coalesce(ccjob, 'None') ~* 'lễ tân|nhân viên kinh doanh dịch' and coalesce(ccjob, 'None') ~* 'chuyên viên (tư vấn|kinh doanh dịch vụ)')
            or (
                -- set_job_id.eq({4233,4192}) (dòng 473,478 gốc): đúng 2 giá trị job_id/job_id_2 =
                -- {4233,4192} (không quan tâm thứ tự) — coi 0 khi NULL giống fillna(0) gốc.
                (coalesce(job_id, 0) = 4233 and coalesce(job_id_2, 0) = 4192)
                or (coalesce(job_id, 0) = 4192 and coalesce(job_id_2, 0) = 4233)
            )
            or (
                -- set_user_job_id.eq({6596,4192}) (dòng 476,479 gốc): id1/id2 (đã ưu tiên user_id
                -- 6596) đúng bằng {6596,4192}.
                (coalesce(id1, 0) = 6596 and coalesce(id2, 0) = 4192)
                or (coalesce(id1, 0) = 4192 and coalesce(id2, 0) = 6596)
            )
        ) as is_ccjob_recept
    from flags3a f3a
),

-- Tỷ lệ chia hoa hồng (dòng 498-538 gốc) — 8 trường hợp ưu tiên theo thứ tự, khớp docstring gốc
ratio as (
    select
        f3.*,
        case
            when coalesce(consultants_2, 0) = 0 or consultants_2 = consultants_1 then 1
            when coalesce(consultants_1, 0) = 0 then 2
            when is_ccjob_recept and is_sell_recept then 3
            when is_sell_dermatology and is_ccjob_dermatology_doctor and (is_group_job_cssdv or not is_dept_recept) then 4
            when is_sell_dermatology and is_ccjob_dermatology_doctor and is_dept_recept and coalesce(company_id, 0) not in (2,3,4,12) then 5
            when consulting_role_1::text = '5' then 6
            when consulting_role_2::text = '5' then 7
            else 0
        end as rto_key
    from flags3 f3
),

ratio2 as (
    select
        r.*,
        case rto_key when 1 then 1.0 when 2 then 0.0 when 3 then 1.0 when 4 then 1.0 when 5 then 1.0 when 6 then 0.7 when 7 then 0.3 else 0.5 end as rto_1,
        case rto_key when 1 then 0.0 when 2 then 1.0 when 3 then 1.0 when 4 then 1.0 when 5 then 1.0 when 6 then 0.3 when 7 then 0.7 else 0.5 end as rto_2
    from ratio r
),

commission as (
    select
        r2.*,
        (rto_1 * payment) as commission_employee,
        (rto_2 * payment) as commission_employee_2,
        (case when rto_1 * rto_2 = 1 then payment / 2.0 else rto_1 * payment end) as commission_department
    from ratio2 r2
),

commission2 as (
    select
        c.*,
        (payment - commission_department) as commission_department_2
    from commission c
),

-- Bán chéo - bán mở rộng (dòng 541-555 gốc)
cross_upsell as (
    select
        c2.*,
        (coalesce(his_service_type, 'None') ~* 'surgery|laser|spa|odo|card') as is_his_service
    from commission2 c2
),

dept_calc as (
    select
        cu.*,
        case
            when coalesce(department_id, 0) in (2617,2601,2562,2553,2348,2315,2309,2301,2251,2215,2199,2198,2153,2141,2120,2108,2103,2084,2070,2066,2054,2053,2048,2046,2045)
                or coalesce(department, 'None') ~* 'thẩm mỹ da|laser|spa|vận hành dịch vụ' then 'Laser_Spa_Card'
            when coalesce(department_id, 0) in (2607,2605,2604,2603,2602,2599,2598,2047)
                or coalesce(department, 'None') ~* 'phẫu thu|gây mê|thay b|dịch vụ khách|quan h|chuyên môn|đại phẫu|tiểu phẫu|điều dưỡng' then 'Surgery'
            when coalesce(department_id, 0) in (2600,2547,2373,2327,2304,2254,2219,2208,2202,2182,2169,2161,2151,2135,2117,2113,2109,2100,2092,2089,2079,2072,2062)
                or coalesce(department, 'None') ~* 'nha|răng' then 'Odontology'
            else department
        end as dept,
        case
            when coalesce(department_id_2, 0) in (2617,2601,2562,2553,2348,2315,2309,2301,2251,2215,2199,2198,2153,2141,2120,2108,2103,2084,2070,2066,2054,2053,2048,2046,2045)
                or coalesce(department_2, 'None') ~* 'thẩm mỹ da|laser|spa|vận hành dịch vụ' then 'Laser_Spa_Card'
            when coalesce(department_id_2, 0) in (2607,2605,2604,2603,2602,2599,2598,2047)
                or coalesce(department_2, 'None') ~* 'phẫu thu|gây mê|thay b|dịch vụ khách|quan h|chuyên môn|đại phẫu|tiểu phẫu|điều dưỡng' then 'Surgery'
            when coalesce(department_id_2, 0) in (2600,2547,2373,2327,2304,2254,2219,2208,2202,2182,2169,2161,2151,2135,2117,2113,2109,2100,2092,2089,2079,2072,2062)
                or coalesce(department_2, 'None') ~* 'nha|răng' then 'Odontology'
            else department_2
        end as dept_2
    from cross_upsell cu
),

ext_calc as (
    select
        dc.*,
        case
            when (not (coalesce(dept, 'None') ~* 'surgery|laser|spa|odo|card')) or (not is_his_service) then ''
            when not (coalesce(dept, 'None') ~* coalesce(his_service_type, 'None')) then 'ext02'
            else 'ext01'
        end as ext,
        case
            when (not (coalesce(dept_2, 'None') ~* 'surgery|laser|spa|odo|card')) or (not is_his_service) then ''
            when not (coalesce(dept_2, 'None') ~* coalesce(his_service_type, 'None')) then 'ext02'
            else 'ext01'
        end as ext_2
    from dept_calc dc
),

upsell_final as (
    select
        ec.*,
        (ext || ',' || ext_2) as extensive_cross_upsell,
        not (
            coalesce(is_no_kpi, false)
            or source_id in (215,216,217,219,80,81,82,83,84,87,88,89,90,124,278,279,280,287,288,289,292,535,569,570)
        ) as is_kpi_branch
    from ext_calc ec
),

-- Thưởng chênh lệch (dòng 564-579 gốc)
bonus_cdt as (
    select
        uf.*,
        (
            is_bonus_commission_back > 0
            and is_price_list_flexible_discount
            and is_kpi_branch
            and type_guarantee is null
        ) as pay_bonus
    from upsell_final uf
),

bonus_raw as (
    select
        bc.*,
        (pay_bonus and payment > 0) as cdt1,
        (pay_bonus and payment < 0 and total_received_cumsum >= total_price_min) as cdt2,
        (pay_bonus and payment < 0 and total_received_cumsum < total_price_min) as cdt3
    from bonus_cdt bc
),

bonus_raw2 as (
    select
        br.*,
        case
            when cdt1 then (total_received_cumsum - total_price_min)
            when cdt2 then payment
            when cdt3 then (payment + (total_price_min - total_received_cumsum))
            else 0
        end as commission_bonus_raw
    from bonus_raw br
),

-- ⚠ Xem cảnh báo #1 đầu file — thứ tự ORDER BY trong LAG này là SUY ĐOÁN, chưa verify.
bonus_shift as (
    select
        br2.*,
        lag(commission_bonus_raw, 1) over (
            partition by brand_etl, clineid, product_id
            order by payment_date, ma_phieu
        ) as commission_bonus_shift1
    from bonus_raw2 br2
),

bonus_final as (
    select
        bs.*,
        case
            when commission_bonus_raw > 0 and payment < 0 then 0
            when cdt1 and coalesce(commission_bonus_shift1, 0) > 0 then commission_bonus_raw - commission_bonus_shift1
            else commission_bonus_raw
        end as commission_bonus
    from bonus_shift bs
),

bonus_split as (
    select
        bf.*,
        (commission_bonus * rto_1) as commission_bonus_employee,
        (commission_bonus * rto_2) as commission_bonus_employee_2,
        (case when rto_1 * rto_2 = 1 then (commission_bonus * rto_1) / 2.0 else (commission_bonus * rto_1) end) as commission_bonus_department
    from bonus_final bf
),

bonus_split2 as (
    select
        bsp.*,
        (commission_bonus - commission_bonus_department) as commission_bonus_department_2
    from bonus_split bsp
),

-- Luỹ kế KPI theo tuần trong tháng (dòng 587-607 gốc) — xem cảnh báo #3 đầu file (w4 chỉ tính đến
-- ngày 28, không phải cả tháng).
weekly as (
    select
        b2.*,
        extract(day from payment_date)::int as d_mth,
        extract(month from payment_date)::int as mth,
        (to_char(payment_date, 'YYYYMM') ||
            case
                when extract(day from payment_date) <= 7 then 'W1'
                when extract(day from payment_date) <= 14 then 'W2'
                when extract(day from payment_date) <= 21 then 'W3'
                else 'W4'
            end
        ) as week_in_mth,
        sum(case when extract(day from payment_date) <= 7 and is_kpi_branch then payment else null end)
            over (partition by extract(month from payment_date), company_id, brand_etl) as payment_kpi_accumulated_w1,
        sum(case when extract(day from payment_date) <= 14 and is_kpi_branch then payment else null end)
            over (partition by extract(month from payment_date), company_id, brand_etl) as payment_kpi_accumulated_w2,
        sum(case when extract(day from payment_date) <= 21 and is_kpi_branch then payment else null end)
            over (partition by extract(month from payment_date), company_id, brand_etl) as payment_kpi_accumulated_w3,
        sum(case when extract(day from payment_date) <= 28 and is_kpi_branch then payment else null end)
            over (partition by extract(month from payment_date), company_id, brand_etl) as payment_kpi_accumulated_w4
    from bonus_split2 b2
)

select
    w.*,
    case
        when d_mth <= 7 then payment_kpi_accumulated_w1
        when d_mth <= 14 then payment_kpi_accumulated_w2
        when d_mth <= 21 then payment_kpi_accumulated_w3
        else payment_kpi_accumulated_w4
    end as payment_kpi_accumulated_w
from weekly w
