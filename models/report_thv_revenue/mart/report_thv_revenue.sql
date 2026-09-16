-- Output cuối của report_thv_revenue: doanh số dịch vụ + nhà thuốc (THV) đã
-- gộp ở stag/rtr_combine, kèm nhóm nguồn báo cáo / nhóm MD-ML. Không cần thêm
-- cột dedup (row_number) như report_thv_sale_online — rtr_combine không có
-- rủi ro fan-out (mỗi dòng int model join 1-1 theo patientrecordid/medicinebillid,
-- không phải join nhiều-nhiều như bên booking/line).

select * from {{ ref('rtr_combine') }}
