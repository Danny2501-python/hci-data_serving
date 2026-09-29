-- Gộp doanh số + mục tiêu của 2 thương hiệu vào 1 bảng (3 model con ở int/:
-- rhtdk_hh, rhtdk_thv_ds, rhtdk_thv_target):
--   - Hồng Hà       (brand_etl = 4): lấy nguyên rhh_ehc_payment_service (đã có
--     sẵn Dịch vụ + Nhà thuốc + Target từ ggs_target_company brand_id = 4).
--   - Tiêu hóa Việt (brand_etl = 8): doanh số từ report_thv_revenue (dịch vụ +
--     nhà thuốc), mục tiêu từ rtr_target_latest (seed rtr_target, bản đang
--     hiệu lực).
--
-- nguon_du_lieu thống nhất 3 giá trị: 'Dịch vụ' / 'Nhà thuốc' / 'Target'
-- (THV đổi từ nguon_doanh_thu dich_vu/nha_thuoc).
--
-- LƯU Ý MỤC TIÊU: THV có nhiều loại chỉ tiêu mỗi tháng (ds, md, ml, dtkd,
-- mgm, loyalty, md_khong_thuoc) — chúng CHỒNG NHAU, không cộng được. Cột
-- loai_chi_tieu cho biết loại; mục tiêu tổng thương hiệu là loai_chi_tieu =
-- 'ds' (HH chỉ có 1 dòng/tháng, cũng gán 'ds'). Khi cộng target tổng phải
-- lọc loai_chi_tieu = 'ds'.
--
-- Cột nguồn:
--   - source_ehc / dm_hoahongnguoigioithieu_nguoigioithieuname: nguồn bên EHC
--     (người giới thiệu / nhóm hoa hồng), cả 2 brand đều có.
--   - erp_source_id_old/old_source_name/erp_source_id_new/new_source_name:
--     nguồn ERP theo id_booking (HH: tên cột gốc; THV: erp_old_*/erp_new_*).
--   - nhom_nguon_baocao/nhom_md_ml_baocao/nguon_sau_mapping: chỉ THV có
--     (HH chưa có bảng nhóm nguồn báo cáo) -> NULL cho HH.
--   - patientcode/invoiceid/pl/roomname/roomname_kb: chỉ HH có -> NULL cho THV.

select * from {{ ref('rhtdk_hh') }}
union all
select * from {{ ref('rhtdk_thv_ds') }}
union all
select * from {{ ref('rhtdk_thv_target') }}
