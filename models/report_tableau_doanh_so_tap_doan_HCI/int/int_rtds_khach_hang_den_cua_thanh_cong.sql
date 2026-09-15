-- Khách hàng đến cửa / thành công — theo ĐÚNG logic hiện có trong workbook "KANGNAM - BỘ CHỈ SỐ
-- KINH DOANH - 2025.twbx" (cặp field KHÔNG giới hạn kênh MD: cd_customer_come/cd_customer_come_
-- deposit — KHÁC với ô "(MD)" hiển thị trên dashboard, 2 khái niệm khác nhau, user đã xác nhận so
-- sánh đúng là với cặp không-MD) — xem LOGIC.md mục 4f, lịch sử trao đổi 2026-09-15.
-- Nguồn report_crm_lead_customer_out_sold — bảng ngoài dbt, job Python/Airflow tạo (xem
-- quentk_3_report_crm_lead_customer_out_sold_New_sys.py). Phủ CẢ 4 THƯƠNG HIỆU: Kangnam/Paris
-- (2026-09-15) + Hồng Hà/Tiêu Hóa Việt (2026-09-15, mở rộng sau khi backfill xong).
--
-- (2026-09-15) brand_etl của bảng gốc đã được backfill/đồng bộ lại ĐÚNG — đã đối chiếu new_product
-- khớp 100% với sandbox (cùng tổng dòng, cùng phân bố brand_etl, cùng số liệu theo tháng). Dùng
-- THẲNG brand_etl, KHÔNG cần suy ra từ report_brand (text) như bản Kangnam/Paris đầu tiên nữa.
--
-- ⚠⚠ PHÁT HIỆN QUAN TRỌNG (2026-09-15) — brand_etl=8 trong bảng NÀY gộp chung CẢ Hồng Hà VÀ Tiêu Hóa
-- Việt (đối chiếu `m_res_company`: brand_etl=8 gồm cả "BỆNH VIỆN HỒNG HÀ" lẫn "Phòng Khám Tiêu Hóa
-- Việt" cùng 1 mã) — HOÀN TOÀN KHÁC với brand_etl dùng ở hệ EHC (`int_rtds_hongha.sql`
-- dùng brand_etl=4, `int_rtds_thv.sql` dùng brand_etl=8 riêng cho THV) — 2 hệ thống mã hoá brand_etl
-- trùng số nhưng KHÁC Ý NGHĨA, không được lẫn lộn. `report_brand` (text) cũng KHÔNG tách được (luôn
-- ='HỒNG HÀ' cho cả 2). Phải tách bằng `report_company` — CHỈ 'Phòng Khám Tiêu Hóa Việt' là THV, còn
-- lại (BỆNH VIỆN HỒNG HÀ/BỆNH VIỆN HỒNG HÀ HCM/...) là Hồng Hà. Bảng này KHÔNG có brand_etl=4 (0
-- dòng) — không liên quan gì đến mã brand_etl=4 của hệ EHC.
-- Data check: cả Hồng Hà lẫn THV đều CHỈ có type_customer_arrived IN ('deposit','outsold',
-- 'outsold_return') — KHÔNG có 'success'/'success_return' (khác Kangnam/Paris có đủ 5 giá trị) —
-- không ảnh hưởng công thức "Thành công" vì Set_success vẫn khớp đúng theo tập con thực có.
--
-- ⚠⚠⚠ CẢNH BÁO DỮ LIỆU (2026-09-15) — Hồng Hà gần như KHÔNG có dữ liệu từ T2/2026 trở đi: bảng gốc
-- ngừng nhận bản ghi mới cho Hồng Hà từ đầu tháng 1/2026 (`create_on` mới nhất = 2026-01-08; T1/2026
-- có 8.407 dòng, từ T2/2026 chỉ còn 0-7 dòng/tháng) — khác hẳn 1 lỗi ĐÃ FIX (đồng bộ brand_etl sai) —
-- đây là 1 lỗi pipeline KHÁC, RIÊNG của Hồng Hà, CHƯA xử lý, không liên quan gì tới việc backfill
-- brand_etl vừa xong. THV/Kangnam/Paris đều có dữ liệu khỏe mạnh, cập nhật đến hiện tại. User đã xác
-- nhận (2026-09-15): CỨ build đủ 4 thương hiệu, KHÔNG chặn lại chờ fix Hồng Hà — nhưng số "Khách đến
-- cửa/thành công" của Hồng Hà từ T2/2026 trở đi SẼ GẦN NHƯ BẰNG 0, cần lưu ý khi hiển thị lên Tableau
-- (dễ hiểu nhầm là brand không hoạt động, thực ra chỉ là bảng nguồn thiếu dữ liệu).
--
-- Định nghĩa (đúng theo Custom SQL + calculated field gốc trong workbook Kangnam, áp dụng chung cho
-- cả 4 thương hiệu — đã bỏ hoàn toàn logic CBNV/Đối ngoại/TPM/bảo hành/no_kpi/amount_paid tự đặt ra
-- ban đầu, xem lịch sử trao đổi 2026-09-15):
--   Dedupe: 1 dòng/(crm_id, brand_etl), lấy dòng có total_received cao nhất (hoà thì lấy clineid lớn
--     nhất) — giống hệt `DISTINCT ON (crm_id, brand_etl) ORDER BY ... COALESCE(total_received,0) DESC,
--     clineid` trong Custom SQL gốc của workbook.
--   "Đến cửa" = customer_come = 'yes' OR (customer_come IS NULL AND arrival_date IS NOT NULL).
--   "Thành công" = "Đến cửa" + type_customer_arrived IN ('deposit','outsold_return','success',
--     'success_return') — ĐÚNG tập "Set_success" của workbook (CÓ tính cả 'deposit').
--   Thời gian: dùng report_date (KHÔNG phải arrival_date) — đúng theo cách workbook gốc group theo
--     tháng.
-- Đã đối chiếu số liệu Kangnam/Paris ra khớp với workbook trước khi chốt (Kangnam T8/2026: 4.313 đến
-- cửa/3.187 thành công) — xem lịch sử trao đổi 2026-09-15. Hồng Hà/THV: KHÔNG có workbook nào để đối
-- chiếu, chỉ áp dụng NHẤT QUÁN cùng công thức đã validate ở Kangnam/Paris.

{{ config(materialized='table') }}

with dedup as (
    select distinct on (crm_id, brand_etl)
        crm_id,
        brand_etl,
        report_company as chi_nhanh,
        report_date,
        arrival_date,
        customer_come,
        type_customer_arrived,
        total_received,
        clineid
    from {{ ref('stg_rtds_report_crm_lead_customer_out_sold') }}
    where brand_etl in (1, 3, 8)
    order by crm_id, brand_etl, coalesce(total_received, 0) desc, clineid
)
select
    crm_id,
    case
        when brand_etl = 1 then 'Kangnam'
        when brand_etl = 3 then 'Paris'
        when brand_etl = 8 and chi_nhanh = 'Phòng Khám Tiêu Hóa Việt' then 'Tiêu Hóa Việt'
        when brand_etl = 8 and chi_nhanh is not null then 'Hồng Hà'
    end as brand,
    chi_nhanh,
    extract(year from report_date)::int as nam,
    extract(month from report_date)::int as thang,
    (type_customer_arrived in ('deposit', 'outsold_return', 'success', 'success_return')) as da_thanh_cong
from dedup
where report_date is not null
  and chi_nhanh is not null
  and (customer_come = 'yes' or (customer_come is null and arrival_date is not null))
