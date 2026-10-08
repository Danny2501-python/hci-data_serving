-- Output cuối của report_hh_thv_ds_kh: doanh số, chỉ tiêu, chi phí ads và
-- SĐT/booking của Hồng Hà (brand_etl = 4) và Tiêu hóa Việt (brand_etl = 8),
-- đã gộp ở stag/rhtdk_combine (xem ghi chú cột ở đó và LOGIC.md). Luôn lọc
-- theo nguon_du_lieu; chỉ tiêu doanh số tổng lọc loai_chi_tieu = 'ds'.

select * from {{ ref('rhtdk_combine') }}
