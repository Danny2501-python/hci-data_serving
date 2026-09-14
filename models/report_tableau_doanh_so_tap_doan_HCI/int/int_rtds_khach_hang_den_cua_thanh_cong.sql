-- Khách hàng đến cửa / thành công theo brand + chi nhánh + tháng — nguồn
-- report_crm_lead_customer_out_sold (bảng ngoài dbt, job Python/Airflow tạo — xem
-- quentk_3_report_crm_lead_customer_out_sold_New_sys.py). Phục vụ 2 chỉ số "Doanh số KPI / Khách hàng
-- đến cửa" và "Doanh số KPI / Khách hàng thành công" — xem LOGIC.md mục 4f, lịch sử trao đổi
-- 2026-09-14.
-- Grain: 1 dòng = 1 booking (bảng gốc là dòng sản phẩm/dịch vụ, nhiều dòng/booking — dedupe bằng
-- bool_or trước khi mart đếm số khách hàng, tránh đếm trùng theo số dòng dịch vụ).
--
-- ⚠ (2026-09-14) brand_etl của bảng gốc đang HỎNG (100% = 0, lỗi đồng bộ sandbox→new_product, CHƯA
-- khắc phục — xem lịch sử trao đổi 2026-09-14). Dùng report_brand (text, không bị lỗi) để lọc/gắn
-- brand thay vì brand_etl. User xác nhận cứ dev logic trước, backfill dữ liệu đúng sau — khi bảng gốc
-- được đồng bộ lại đúng, model này build lại là ra số đúng, không cần sửa thêm.
-- Bảng gốc hiện KHÔNG có dữ liệu Tiêu Hóa Việt (chỉ Hồng Hà/Kangnam/Paris + vài dòng rác SCI
-- GROUP/Đông Á, đã loại ở where).
--
-- Định nghĩa (⚠ GIẢ ĐỊNH BAN ĐẦU — CẦN USER XÁC NHẬN LẠI TRƯỚC KHI DÙNG SỐ LIỆU CHÍNH THỨC):
--   - "Đến cửa": customer_come = 'yes' (khách đã đến khám/tư vấn, không phân biệt có mua hay không).
--   - "Thành công": type_customer_arrived IN ('success', 'success_return') (đã chốt mua/thành công).
--     KHÔNG tính 'deposit' (mới đặt cọc, chưa chắc thành công cuối cùng) vào "thành công".

{{ config(materialized='table') }}

with base as (
    select
        crm_id,
        booking,
        case report_brand
            when 'HỒNG HÀ' then 'Hồng Hà'
            when 'KANGNAM' then 'Kangnam'
            when 'PARIS' then 'Paris'
        end as brand,
        report_company as chi_nhanh,
        extract(year from report_date)::int as nam,
        extract(month from report_date)::int as thang,
        customer_come,
        type_customer_arrived
    from {{ ref('stg_rtds_report_crm_lead_customer_out_sold') }}
    where report_brand in ('HỒNG HÀ', 'KANGNAM', 'PARIS')
)
select
    crm_id,
    booking,
    brand,
    chi_nhanh,
    nam,
    thang,
    bool_or(customer_come = 'yes') as da_den_cua,
    bool_or(type_customer_arrived in ('success', 'success_return')) as da_thanh_cong
from base
group by crm_id, booking, brand, chi_nhanh, nam, thang
