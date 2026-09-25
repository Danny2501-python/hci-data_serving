-- Output cuối của report_hh_thv_ds_kh: doanh số + mục tiêu Hồng Hà (brand_etl = 4)
-- và Tiêu hóa Việt (brand_etl = 8), đã gộp ở stag/rhtdk_combine (xem ghi chú
-- cột/mục tiêu ở đó). Khi cộng mục tiêu tổng phải lọc loai_chi_tieu = 'ds'.

select * from {{ ref('rhtdk_combine') }}
