-- Port 1:1 từ DAG Airflow `quentk_3_report_kpi_bonus_commission_New_sys.py`
-- (D:\Pythoncode\HCI_System\jupiter_sand_box\quentk_3_report_kpi_bonus_commission_New_sys.py,
-- hàm `step1_transform_commission`, biến `query`/`df_payment`, dòng 244-338) — tương ứng bảng
-- `df_payment` trong pandas gốc. Đây là phần THUẦN SQL trong script gốc (không qua pandas), nên
-- port cơ học 1:1, chỉ đổi tên bảng nguồn sang source()/ref() (Jinja) và tính lại
-- `limit_start_date` bằng SQL thay vì Python.
--
-- `limit_start_date` (bản gốc): datetrunc = ngày-đầu-tháng của (hôm nay trừ 15 ngày), nhưng KHÔNG
-- được sớm hơn `date_sys` (mốc sàn cố định, bản gốc hardcode 01/08/2026 — script gốc note "Hệ
-- thống data mới phân tách thương hiệu" từ 01/08/2025, còn mốc 01/08/2026 là mốc sàn được nâng dần
-- tay theo thời gian để giới hạn khối lượng xử lý lại — xem comment đầu file gốc). Đưa mốc sàn này
-- thành dbt var `rkbc_floor_date` (khai trong dbt_project.yml) thay vì hardcode trong SQL, để cập
-- nhật không cần sửa code — PHẢI nâng var này định kỳ giống cách người viết script gốc vẫn làm tay.
--
-- (2026-08-27) materialized='table' (KHÔNG phải 'ephemeral' như bản đầu) — tránh CTE chồng CTE quá
-- sâu khi step1_commission (model sau) nhúng thẳng vào, giảm tải cho query planner. Đã thử dùng
-- temp table thật qua pre_hook nhưng gặp lỗi dbt: nhiều lệnh ref() bên trong khối Jinja set-block
-- dùng làm chuỗi pre_hook bị resolve SAI (nhầm thành chính bảng model hiện tại) — không an toàn cho
-- pipeline tính hoa hồng, đã bỏ hướng đó, quay lại làm model dbt riêng như bản đầu.
{{ config(materialized='table') }}

with limit_date as (
    select greatest(
        date_trunc('month', current_date - interval '15 days')::date,
        '{{ var("rkbc_floor_date", "2026-08-01") }}'::date
    ) as ld
),

limit_crm_id as (      --- Giới hạn các Booking phát sinh Doanh số trong khoảng thời gian muốn cập nhật dữ liệu
    select distinct crm_id, brand_etl
    from {{ ref('stag_payment_transfer') }}
    where payment_date >= (select ld from limit_date) and payment_date < '3000-01-01'
),

consults as (          	--- Thông tin Lễ tân đầu tiên tư vấn -> điền vào những dòng dịch vụ có Tư vấn viên = NULL
    select
        scic.id, lm.crm_id, scic.crm_line_id as clineid, scic.user_id, scic."role", scic.data_union, lm.brand_etl,
        row_number() over (partition by scic.crm_id, scic.crm_line_id order by case when scic."role" = 'recept' then 1 else 99 end) as rn_cline_consult,
        count(scic.id) over (partition by scic.crm_id, scic.crm_line_id, scic."role") as count_consult_in_role
    from {{ ref('stg_rkbc_stag_crm_information_consultant') }} scic
    inner join limit_crm_id lm on scic.crm_id = lm.crm_id and scic.brand_etl = lm.brand_etl
),

crm_lead_crop as ( 		--- Thông tin khách hàng, Booking
    select
        cl.id as crm_id_join, cl.type_crm_id, cl.name as booking, cl.type_data_partner,
        cl.code_customer, cl.contact_name, cl.arrival_date, cl.create_by,
        cl.partner_id, cl.note, cl.source_id, ru.login, cl.brand_etl
    from {{ ref('stg_rkbc_crm_lead') }} cl
    left join {{ ref('stg_rkbc_res_users') }} ru on cl.create_by = ru.id and cl.brand_etl = ru.brand_etl
    inner join limit_crm_id lm on cl.id = lm.crm_id and cl.brand_etl = lm.brand_etl
),

payments as (  			--- Doanh số. Đánh thứ tự lần thanh toán Booking/Dịch vụ
    select
        spt.*,
        case when round(spt.total_received_cumsum) = round(spt.total) then true end as is_bonus_commission,    --- Kiểm tra lũy kế số tiền đã thu đã bằng tổng phải thu? Cơ chế thưởng chênh lệch
        lag(spt.total_received_cumsum, 1) over (partition by spt.clineid, spt.product_id order by spt.payment_date, spt.ma_phieu) as total_received_cumsum_lag1,
        coalesce(spt.consultants_1, c.user_id) as consultants,
        case when spt.consultants_1 = spt.consultants_2 then null else spt.consultants_2 end as consultants_2_fix
    from {{ ref('stag_payment_transfer') }} spt
    left join (select * from consults where rn_cline_consult = 1) c on (spt.crm_id, spt.clineid) = (c.crm_id, c.clineid)
    inner join limit_crm_id lm on spt.crm_id = lm.crm_id and spt.brand_etl = lm.brand_etl
)

select
    pm.*,
    -- (cl.* rút gọn, KHÔNG lấy cl.brand_etl) — bản pandas gốc SELECT pm.* rồi cl.* nối sau, dùng
    -- `df.columns.duplicated()` tự loại cột trùng tên GIỮ CỘT ĐẦU TIÊN — pm.brand_etl (từ
    -- stag_payment_transfer) xuất hiện trước cl.brand_etl (từ crm_lead) nên cl.brand_etl bị loại,
    -- KHÔNG phải lỗi thiếu cột. Liệt kê tường minh 12 cột còn lại của cl (bỏ brand_etl) để khớp.
    cl.crm_id_join, cl.type_crm_id, cl.booking, cl.type_data_partner,
    cl.code_customer, cl.contact_name, cl.arrival_date, cl.create_by,
    cl.partner_id, cl.note, cl.source_id, cl.login,
    sp.product_ctg_id,
    sp.his_service_type,
    sp.surgery_type,
    sp.product_category,
    sp.product,
    sp.kpi_point, sp.kpi_point_num,
    sp.is_no_kpi,
    case when cline.type_guarantee_2 = 'totality' then '11'
        when cline.type_guarantee_2 = 'not_totality' then '10'
        when cline.type_guarantee is not null then cline.type_guarantee
        when cline.initial_product_id is not null then '99'    				--- Khong xac dinh loai bao hanh
        end as type_guarantee,
    cline.discount_percent, 		--- Chiet khau MKT %
    cline.discount_cash, 			--- Chieu khau MKT tien mat
    cline.other_discount, 			--- Chiet khau MKT khac
    cline.sale_to, 					--- Chiet khau MKT con
    cline.discount_cs_percent,  	--- Chiet khau co so %
    cline.discount_cs_amount, 		--- Chiet khau co so tien mat
    cline.total_discount_review, 	--- Chiet khau co so giam sau
    cline.total_before_discount,
    cline.total_discount,
    coalesce(cline.total, clinep.total) as total_last,
    coalesce(cline.total_received, clinep.total_received) as total_received_last,
    case when coalesce(cline.total_before_discount, 0) > 0 then cline.total_discount / cline.total_before_discount end as total_discount_percent,
    coalesce(cline.price_min, ppi.price_min) as price_min,
    coalesce(cline.source_extend_id, clinep.source_extend_id) as source_extend_id,
    case when clinep.id is null then cline.extensive_source_classification end as extensive_source_classification,
    case when clinep.id is null then cline.reason_line_cancel end as reason_line_cancel,
    ss.category_id as category_source_id, ss.category_source, ss."source",
    coalesce(sse."source", ssep."source") as source_extend,
    pp."name" as price_list,
    case when pp.id in (115, 108, 111, 126) and coalesce(cline.price_min, 0) > 0 then true end as is_price_list_flexible_discount,
    cline.price_min * pm.quantity * pm.uom_price as total_price_min,
    sum(case when is_bonus_commission then 1 else 0 end) over (partition by pm.crm_id, pm.clineid, pm.product_id order by pm.payment_date, pm.ma_phieu, pm.total_received_cumsum) as is_bonus_commission_back,
    min(case when is_bonus_commission then pm.payment_date end) over (partition by pm.crm_id, pm.clineid, pm.product_id) as payment_date_complete_debt,
    -- rc.brand_id KHÔNG lấy (trùng tên "brand_id" với pm.brand_id đã có ở đầu SELECT — cùng lý do
    -- dedup ở trên; giá trị "brand_id" dùng xuyên suốt các bước sau LÀ pm.brand_id/spt.brand_id,
    -- KHÔNG PHẢI m_res_company.brand_id — giữ đúng hành vi gốc, đừng "sửa" tưởng nhầm là thiếu cột).
    orc.brand_id as org_brand_id, rc."name" as company, orc."name" as org_company,
    null::int4 as org_group_clineid,
    null::float8 as total_recept_sell
from payments pm
left join crm_lead_crop cl on pm.crm_id = cl.crm_id_join and cl.brand_etl = pm.brand_etl
left join {{ ref('stg_rkbc_crm_line') }} cline on (pm.clineid, pm.product_id, pm.brand_etl) = (cline.id, cline.product_id, cline.brand_etl)
left join {{ ref('stg_rkbc_crm_line_product') }} clinep on (pm.clineid, pm.product_id, pm.brand_etl) = (clinep.id, clinep.product_id, clinep.brand_etl)
left join (
    select product_id, pricelist_id, max(price_min) as price_min
    from {{ ref('stg_rkbc_product_pricelist_item') }}
    group by product_id, pricelist_id
) ppi on (cline.product_id, cline.price_list_id) = (ppi.product_id, ppi.pricelist_id)
left join {{ ref('stg_rkbc_view_stag_products') }} sp on pm.product_id = sp.product_id and pm.brand_etl = sp.brand_etl
left join {{ ref('stg_rkbc_m_res_company') }} rc on rc.id = pm.company_id and rc.brand_etl = pm.brand_etl
left join {{ ref('stg_rkbc_m_res_company') }} orc on orc.id = pm.orgcompany_id and orc.brand_etl = pm.brand_etl
left join {{ ref('stg_rkbc_stag_sources') }} ss on cl.source_id = ss.old_id
left join {{ ref('stg_rkbc_stag_sources') }} sse on cline.source_extend_id = sse.old_id
left join {{ ref('stg_rkbc_stag_sources') }} ssep on clinep.source_extend_id = ssep.old_id
left join {{ ref('stg_rkbc_product_pricelist') }} pp on pm.price_list_id = pp.id and pp.brand_etl = pm.brand_etl
