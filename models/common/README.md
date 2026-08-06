# Folder `common`

Các model staging **dùng chung** cho nhiều báo cáo khác nhau trong `data_serving` — không gắn
riêng với 1 report cụ thể, chủ yếu xoay quanh grain **booking (`crm_lead`)** và **dòng dịch vụ
(`crm_line`, gọi tắt "cline")** của thương hiệu Kangnam (`brand_etl = 1`).

Toàn bộ source dùng trong folder khai báo tại `sources_common.yml` (source group `crm_base`,
schema `public`).

## Danh sách model

| Model | Materialized | Vai trò |
|---|---|---|
| `stg_booking_id_co_tien_tc` | ephemeral | Danh sách `crm_id` (booking) đã "có tiền thành công": `stage_id = 4` và tổng payment > 0. Dùng làm điều kiện lọc đầu vào cho các model khác trong folder. |
| `stg_booking_nhom_dich_vu_chinh` | ephemeral | Xác định **nhóm dịch vụ chính** của từng booking = `view_stag_products.product_group` của dòng dịch vụ (cline) có `cln.id` nhỏ nhất trong booking — khớp logic với `view_stag_crm_lead_first_product_group` bên DB sandbox (`staging_sci`). |
| `stg_booking_xet_ban_cheo` | **view** | Gắn nhãn **`is_cross_sale`** (bán chéo) cho từng dòng dịch vụ, theo business line chính của khách hàng và mốc 6 tháng. |
| `stg_common_tongquan_khachhang` | table/view (không khai báo `config`) | Bảng tổng quan khách hàng chi tiết theo từng dòng dịch vụ + payment (khách, ngày đến/hẹn/tạo/thanh toán, doanh số, chi nhánh, trạng thái...) — nguồn cho các báo cáo tổng quan khách hàng. |
| `stg_dv_khach_hang_quan_tam` | ephemeral | Nhóm dịch vụ (`product_group`, lấy trực tiếp từ `view_stag_products.product_group`) mà khách hàng **quan tâm đầu tiên** trong mỗi booking (dòng dịch vụ có `cline_created_date`/`cline_id` sớm nhất). |

Chi tiết logic từng model (CTE, quy tắc, công thức) xem **`LOGIC.md`**. Các bug/gotcha kỹ thuật
đã gặp khi build (id trùng chéo brand_etl, fan-out payment, tie-break ORDER BY, nhầm cột
service_id/product_id...) xem **`knowledge.md`** — nên đọc trước khi thêm join mới vào các bảng
nguồn `crm_line`, `crm_lead`, `view_stag_products`, `stag_payment_transfer`, hoặc các bảng `sh_*`
(hệ thống phiếu khám/walkin).

## Lưu ý chung

- Các model còn lại (trừ `stg_common_tongquan_khachhang` và `stg_booking_xet_ban_cheo`) đều
  `materialized = 'ephemeral'` — không tạo bảng/view vật lý riêng, được inline thành CTE vào model
  nào `ref()` tới.
- `stg_booking_xet_ban_cheo` được đổi sang `materialized = 'view'` để có thể query trực tiếp
  (kiểm tra dữ liệu bán chéo theo khách hàng/booking mà không cần dựng bảng tạm `check_*`).
- `stg_booking_nhom_dich_vu_chinh` và `stg_booking_xet_ban_cheo` là 2 model có logic phức tạp nhất
  trong folder, được xây dựng và kiểm chứng kỹ qua nhiều vòng đối chiếu dữ liệu thực tế (query
  trực tiếp DB, dựng bảng vật lý tạm `check_*` để soát từng khách hàng cụ thể) — xem lịch sử build
  trong `knowledge.md` để hiểu vì sao logic có dạng như hiện tại.
- **[Đổi 2026-08-05]** `stg_dv_khach_hang_quan_tam` và `stg_booking_nhom_dich_vu_chinh` giờ **cùng
  dùng chung** `view_stag_products.product_group` (đã bake sẵn CASE WHEN trong view, khớp 100% với
  `staging_sci` — DB sandbox) thay vì mỗi model tự tính CASE riêng. Trước đây `stg_dv_khach_hang_quan_tam`
  dùng nhãn 9 nhóm có tiền tố số (`1.MẮT`...`9.WELLNESS`) và có thêm điều kiện `category_source_code
  = 'MBS'` (theo nguồn khách); giờ nhãn đổi sang đúng dạng `view_stag_products.product_group`
  (`PTTM MẮT`, `BEAUTY & SPA`, `SẢN PHẨM`... không tiền tố số), không còn điều kiện MBS. Vẫn khác
  `business_line` (5 nhóm PTTM/Beauty & Spa/Nha khoa/Wellness/Weight Loss/Khác, dùng ở
  `stg_booking_xet_ban_cheo`) — không dùng lẫn 2 cách phân nhóm này với nhau. Xem đối chiếu dữ liệu
  thật với sandbox trong `knowledge.md` mục 8.
