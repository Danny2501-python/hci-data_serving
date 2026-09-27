-- Test CHẶN cho báo cáo tập đoàn HCI (tag rtds): bảng nguồn report_crm_lead_customer_out_sold phải còn đủ
-- dữ liệu Kangnam trước khi build các model khách hàng đến cửa/thành công.
--
-- Vì sao (2026-09-27): bảng new_product.report_crm_lead_customer_out_sold đã 3 lần bị xoá gần hết dữ liệu
-- brand 1/3/8 (16/09, 26/09, 27/09) — 1 job clone từ job của Quế trỏ nhầm vào new_product chạy 05:20
-- `DELETE ... WHERE write_date >= '2025-08-01' AND brand_etl <> 0` rồi không nạp lại được → Kangnam chỉ còn
-- ~12K dòng (bình thường ~255K). Job clone đã tắt, test này để lần sau nếu nguồn hỏng thì `dbt build`
-- DỪNG ở đây: các model phía sau (int/mart khách hàng, report_rtds_doanh_so_target_thang_tableau) bị SKIP,
-- bảng báo cáo GIỮ NGUYÊN số của lần build tốt gần nhất thay vì ra khách Kangnam/Paris trống.
-- ⚠ Khi test fail, report_rtds_doanh_so_target_thang_tableau cũng không được cập nhật doanh số mới.
--
-- Ngưỡng: var `rtds_out_sold_min_rows_kangnam` (dbt_project.yml, mặc định 200000). Test trả về 1 dòng
-- (= FAIL) khi số dòng brand_etl = 1 thấp hơn ngưỡng.

{{ config(severity='error', tags=['rtds']) }}

select
    count(*) as so_dong_kangnam,
    {{ var('rtds_out_sold_min_rows_kangnam', 200000) }} as nguong_toi_thieu
from {{ ref('stg_rtds_report_crm_lead_customer_out_sold') }}
where brand_etl = 1
having count(*) < {{ var('rtds_out_sold_min_rows_kangnam', 200000) }}
