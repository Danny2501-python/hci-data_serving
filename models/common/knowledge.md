# common — Knowledge (bug đã phát hiện & fix)

Ghi lại trong quá trình build `stg_booking_xet_ban_cheo.sql` và `stg_booking_nhom_dich_vu_chinh.sql`.
Các gotcha này áp dụng chung cho mọi model mới join vào các bảng nguồn liên quan trong
`data_serving` (không riêng 2 model trên).

## 1. `id` trùng chéo giữa các `brand_etl`

Kho dữ liệu này gộp nhiều thương hiệu về cùng 1 cấu trúc bảng, nên cột `id` (khóa chính) của rất
nhiều bảng **KHÔNG unique toàn cục** — cùng 1 giá trị `id` có thể thuộc nhiều `brand_etl` khác
nhau, với dữ liệu hoàn toàn khác nhau. Đã xác nhận với: `crm_line.id`, `crm_lead.id`, `product_id`
và `service_id` trong `view_stag_products` (99,010 dòng nhưng chỉ 4,850 `service_id` distinct),
`sh_medical_appointment_register_walkin.id` (trùng tới 5 brand), `m_res_company.id`.

**Hệ quả:** mọi join dùng `id` phải kèm điều kiện `brand_etl` khớp đúng, nếu không sẽ âm thầm lấy
nhầm dữ liệu chéo brand (không báo lỗi, chỉ ra kết quả sai/thiếu/fan-out).

**Cạm bẫy phụ:** cột `brand_etl` nằm TRÊN CHÍNH bảng cầu/rel (vd
`crm_line_sh_medical_appointment_register_walkin_rel`, `sh_walkin_service_rel`,
`crm_lead_product_category_rel`) có thể tự nó không đáng tin cậy để dùng làm điều kiện lọc — hoặc
NGƯỢC LẠI, có thể bị hiểu NHẦM là "không đáng tin" nếu test bằng 1 join khác THIẾU brand_etl ở
bước trước đó (id phía kia cũng trùng chéo brand → join thiếu brand_etl tạo ra kết quả chéo giả
trông giống brand_etl bảng rel bị sai). Cách xử lý an toàn: luôn dùng `brand_etl` của bảng **gốc,
đáng tin nhất trong chuỗi** (vd `sh_medical_appointment_register_walkin.brand_etl`, đã verify khớp
đúng `crm_lead.brand_etl` qua `booking_id`) làm mốc so sánh cho MỌI bảng join tiếp theo, thay vì
tin brand_etl của từng bảng rel riêng lẻ.

Ví dụ đo được: join `sh_walkin_service_rel → view_stag_products` theo `service_id` mà thiếu
`brand_etl` sẽ fan-out ~5 lần (586,402 dòng thay vì 121,780 dòng đúng).

## 2. `stag_payment_transfer` không phải 1-dòng-1-`clineid`

1 `clineid` có thể có nhiều dòng trong `stag_payment_transfer` (trả góp/nhiều đợt thanh toán —
xác nhận qua cột `rnk_clineid_pmdate` có sẵn trong bảng, cho thấy grain gốc là nhiều dòng/clineid).
Join thẳng không dedupe sẽ nhân bản dòng cline, làm sai mọi `ROW_NUMBER()`/`FIRST_VALUE()` tính
theo cline. Đo được ~17% cline trong scope bị nhân bản.

**Fix:** luôn `GROUP BY clineid, brand_etl` trước khi join, lấy `MIN(payment_date)` (ngày thanh
toán đầu) và `SUM(payment)` (tổng payment) — xem CTE `cline` trong
`stg_booking_xet_ban_cheo.sql`.

## 3. `ORDER BY` trên timestamp không có tie-break → kết quả không tái lập được

Nhiều dòng `crm_line` trong cùng 1 booking có `create_date` **giống hệt nhau tới mili-giây**
(insert cùng batch). `ROW_NUMBER()`/`FIRST_VALUE() OVER (... ORDER BY cline_created_date)` không
tiêu chí phụ sẽ cho kết quả khác nhau giữa các lần chạy (Postgres chọn ngẫu nhiên thứ tự trong
nhóm trùng giờ). Từng verify bằng cách chạy lại cùng 1 query 2 lần trên cùng dữ liệu và ra
`main_bl_customer` khác nhau cho cùng 1 khách hàng.

**Fix:** luôn thêm `cline_id` (hoặc id riêng của bảng) làm tiêu chí phụ cuối `ORDER BY`:
`ORDER BY cline_created_date, cline_id`.

## 4. `view_stag_products` có CẢ `service_id` lẫn `product_id` — 2 cột khác nhau

Không nhầm với bảng tên gần giống `stag_products` (43 cột, có `smhcsid`, KHÔNG có `service_id`).

- `crm_line.product_id` → nối `view_stag_products.product_id` (đúng).
- `sh_walkin_service_rel.service_id` → phải nối `view_stag_products.service_id`, KHÔNG PHẢI
  `product_id` (2 hệ id riêng biệt dù cùng nằm trên 1 dòng — vd `service_id=1094` có
  `product_id=1161` khác hẳn).

Join nhầm cột khiến rất nhiều `service_id` hợp lệ bị coi là "không map được sản phẩm" →
`main_bl_completed_date` NULL sai hàng loạt (độ phủ tăng từ ~42% lên ~76.5% sau khi sửa).

**Bài học chung:** trước khi join `*_id` vào bảng lạ, luôn đọc `information_schema.columns` thật
để xác nhận đúng tên cột đích, không suy đoán theo tên cột nguồn.

## 5. `crm_lead.code_booking` rỗng 100% — mã booking thật nằm ở `crm_lead.name`

Cột `code_booking` không được populate cho `brand_etl=1` (0/249,828 dòng có giá trị). Mã booking
dạng `BOOK-YYMMDD-NNNNN` (vd `BOOK-260325-00049`) thực chất nằm ở cột `crm_lead.name`.

## 6. custom_fields id=9794 — `value` trong JSON là `value_id`, không phải `custom_field_id`

`cs_deal_detail_api_v2.custom_fields` là JSON array `[{id, value}, ...]`. Với phần tử
`id=9794` ("Nhóm dịch vụ chính"), `value` là **`cs_custom_fields.value_id`** (một mã lựa chọn cụ
thể, vd `151797`), không phải `custom_field_id` (luôn là hằng số `'9794'` cho mọi lựa chọn của
field này). Join đúng: `ccf.value_id = (cf_elem->>'value') AND ccf.custom_field_id = '9794'`.

Phần lớn `value_lable` có định dạng `"[MÃ] Tên dịch vụ"` (cần bóc mã bằng
`SPLIT_PART(value_lable, ']', 2)`), nhưng có ngoại lệ không có dấu `]` (vd `"NHA KHOA"`) — phải
`CASE WHEN value_lable LIKE '%]%' THEN ... ELSE value_lable END`, nếu không sẽ mất dữ liệu (ra
chuỗi rỗng).
