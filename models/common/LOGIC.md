# common — Logic nghiệp vụ

## 1. stg_booking_id_co_tien_tc.sql

Danh sách `crm_id` (booking) đã "có tiền thành công": `crm_lead.stage_id = 4` và tổng
`stag_payment_transfer.payment` (group theo `crm_id, brand_etl`) > 0. Dùng làm điều kiện lọc
đầu vào cho các model booking khác trong `common/`.

## 2. stg_booking_nhom_dich_vu_chinh.sql

Xác định **nhóm dịch vụ chính của booking** (`crm_id`) và map sang `business_line`. Chỉ tính
`brand_etl = 1` (Kangnam).

### Nguồn theo thứ tự ưu tiên (lấy nguồn đầu tiên có dữ liệu)

1. **`crm_lead_product_category_rel`** → join `product_category.name`. 1 `lead_id` có thể gắn
   nhiều category cùng lúc (~76 trường hợp quan sát được, thường là các cặp dịch vụ hay đi kèm
   nhau, vd "PTTM - Giảm mỡ" + "PTTM - Nâng ngực") → lấy category **xuất hiện đầu tiên** theo
   `ingestion_timestamp`.
2. **`custom_fields` id=9794** ("Nhóm dịch vụ chính") trên `cs_deal_detail_api_v2.custom_fields`
   (JSON array `{id, value}`) — nối qua `crm_lead.ticket_id = cs_deal_detail_api_v2.id`. `value`
   trong JSON thực chất là `cs_custom_fields.value_id` (không phải `custom_field_id`) — join
   `value_id` kèm `custom_field_id='9794'` để lấy `value_lable`, rồi bóc phần mã trong ngoặc
   vuông (`"[KNP00001] PTTM MẮT"` → `"PTTM MẮT"`; nếu không có `]` — vd `"NHA KHOA"` — thì giữ
   nguyên).
3. **Fallback**: `product_category` (từ `view_stag_products`) của dòng dịch vụ (cline) có
   `create_date` sớm nhất trong booking.

### Map sang business_line

`nhom_dich_vu_chinh` (text) → tra trong `view_stag_products` (lấy `his_service_type` xuất hiện
nhiều nhất/mode cho mỗi `product_category`, vì 1 category có thể gắn nhiều `his_service_type`
khác nhau) → áp CASE business_line giống hệt mục 3 bên dưới. Category không khớp được tên với
`view_stag_products.product_category` (khác hệ đặt tên giữa các nguồn) thì `business_line` trả
về **NULL**, không ép về `'Khác'`, để phân biệt "không xác định được" với "có his_service_type
nhưng không thuộc 5 nhóm chính".

## 3. stg_booking_xet_ban_cheo.sql (materialized = `view`)

Gắn nhãn **bán chéo (`is_cross_sale`)** cho từng dòng dịch vụ (cline) của khách hàng
(`code_customer`). Chỉ tính `brand_etl = 1`, booking `type = 'opportunity'` (không tính `lead`
chưa thành cơ hội), và chỉ các booking thuộc `stg_booking_id_co_tien_tc` (đã có tiền thành công).

Model này `materialized = 'view'` (khác các model còn lại trong folder đều là `ephemeral`) để có
thể query trực tiếp phục vụ kiểm tra dữ liệu (theo khách hàng, theo booking, tổng hợp doanh số
theo chi nhánh/tháng...) mà không cần dựng bảng tạm.

### CTE `cline` — grain: 1 dòng dịch vụ

- `business_line`: map từ `view_stag_products.his_service_type`:
  `Surgery→PTTM`, `Spa/Laser/Card→Beauty & Spa`, `Odontology→Nha khoa`, `wellness→Wellness`,
  `weight_loss→Weight Loss`, còn lại → `Khác`.
- `cline_payment_date` / `cline_total_payment`: `MIN(payment_date)` / `SUM(payment)` từ
  `stag_payment_transfer` group theo `(clineid, brand_etl)` — **bắt buộc** vì 1 cline có thể có
  nhiều dòng payment (trả góp/nhiều đợt), nếu không dedupe sẽ fan-out (xem `knowledge.md`).
- `booking_report_date`: `arrival_date` nếu khách đã đến (`customer_come='yes'`), else
  `booking_date`.

### CTE `rnk_bl_cline` / `paid_bl_cline` — đánh số thứ tự

- `cus_bl_cline_order`, `crm_cline_order`, `cus_cline_order`: thứ tự cline theo
  `(business_line, code_customer)` / `(crm_id)` / `(code_customer)`, `ORDER BY cline_created_date,
  cline_id` (kèm `cline_id` để tie-break — xem `knowledge.md`).
- `paid_bl_cline`: đánh số **`cus_bl_paid_order`** — chỉ tính trên các dòng có
  `cline_total_payment > 0`, bỏ qua dòng hủy/chưa thanh toán khi xác định "lần mua đầu tiên" và
  khi tìm dòng liền trước để tính khoảng cách 6 tháng. Sắp theo **`cline_payment_date`** (không
  phải `cline_created_date`) — nhất quán với giá trị dùng so sánh khoảng cách 6 tháng bên dưới, để
  tránh trường hợp dòng tạo sau nhưng thanh toán trước dòng liền trước theo thứ tự tạo (từng gây
  `diff_date_order_bl` âm khi còn sắp theo `cline_created_date`).

### CTE `labeling_1`

- `is_line_over_6_months_in_bl`: so sánh `cline_payment_date` của dòng hiện tại với dòng
  **liền trước cùng BL đã có payment** (`prev_pbc`, theo `cus_bl_paid_order - 1`) — nếu không có
  dòng trước (lần mua đầu) → false; nếu có và cách nhau > 6 tháng → true.
- `main_bl_customer`: business_line của dòng dịch vụ **đầu tiên** trong toàn bộ lịch sử khách
  hàng (`first_value(...) over (partition by code_customer order by cline_created_date,
  cline_id)`) — không phụ thuộc payment/stage, chỉ theo ngày tạo sớm nhất.
- `main_bl_bk`: tương tự nhưng theo từng booking (`crm_id`) riêng — hiện **không còn dùng** trong
  `is_cross_sale` (đã đơn giản hóa), chỉ giữ lại để tham khảo.
- `main_product_category_id` / `main_product_category`: `product_ctg_id`/`product_category`
  (`view_stag_products`) của dòng dịch vụ **đầu tiên** trong lịch sử khách hàng — cùng cách tính
  (cùng window) với `main_bl_customer`, chỉ khác lấy category thay vì business_line. Đại diện cho
  nhóm dịch vụ khách quan tâm ban đầu.
- `prev_bl_order_date` / `diff_date_order_bl` / `prev_bl_crm_id` / `prev_bl_booking`: thông tin
  của dòng liền trước cùng `(business_line, code_customer)` đã có payment (`prev_pbc`) — chính là
  dữ liệu dùng để tính `is_line_over_6_months_in_bl`. `diff_date_order_bl` = số ngày giữa
  `cline_payment_date` hiện tại và `prev_bl_order_date` (NULL nếu là lần mua đầu tiên của BL đó,
  tức không có `prev_pbc`).

### CTE `main_bl_walkin` — điều kiện tiên quyết

Phiếu khám (`sh_medical_appointment_register_walkin`, `state='Completed'`) **đầu tiên** (theo
`service_date_start`, tie-break bằng `w.id`) thuộc dịch vụ có business_line = `main_bl_customer`
của khách hàng, gán chung cho toàn bộ `code_customer` đó: `main_bl_completed_date`
(`service_date_start`), `main_bl_order_id` (`sale_order_id` của đúng bản ghi walkin đó),
`main_bl_walkin_done` (mã phiếu khám — `sh_medical_appointment_register_walkin.name` — của đúng
bản ghi walkin đó), `main_bl_booking_org` (mã booking gốc — `crm_lead.name` — chứa bản ghi walkin
đó).

Dùng `ROW_NUMBER()` (không phải `MIN()`) để chốt đúng 1 bản ghi walkin cụ thể, nhờ đó lấy kèm
được `sale_order_id`/booking gốc của chính bản ghi đó.

Liên hệ: `sh_medical_appointment_register_walkin.booking_id = crm_lead.id` →
`sh_walkin_service_rel.walkin_id = walkin.id` → `service_id` → **`view_stag_products.service_id`**
(không phải `product_id` — xem `knowledge.md`).

### Quy tắc `is_cross_sale` (final SELECT)

```
1. main_bl_completed_date IS NULL                         → false (chưa hoàn thành main BL)
2. business_line = main_bl_customer                        → false (thuộc main BL, không phải bán chéo)
3. cline_total_payment <= 0 (dòng này không có payment)     → false ("bán thành công" là điều kiện bắt buộc)
4. EXISTS (trong cùng booking crm_id + cùng business_line) ít nhất 1 dòng khác thỏa:
       cline_total_payment > 0
       AND (cus_bl_paid_order = 1 OR is_line_over_6_months_in_bl = true)
   (tính bằng bool_or(...) OVER (PARTITION BY crm_id, business_line))
                                                             → true
5. else                                                     → false
```

Diễn giải: một booking (`crm_id`) được coi là "lần bán bán chéo" cho 1 business_line khác main BL
nếu nó chứa ít nhất 1 dòng dịch vụ "kích hoạt" — có payment thật, và (a) là lần mua có payment đầu
tiên của BL đó, hoặc (b) cách lần mua có payment liền trước của BL đó > 6 tháng. Khi booking đó đã
được kích hoạt, **toàn bộ** các dòng dịch vụ có payment > 0 của cùng BL đó trong cùng booking đều
được gắn `is_cross_sale = true`, không chỉ riêng dòng kích hoạt (vd khách mua 2 dịch vụ Beauty &
Spa trong cùng 1 booking bán chéo → cả 2 dòng đều tính, dù chỉ dòng có `cline_created_date` sớm
hơn mới thỏa `cus_bl_paid_order = 1`).

Mua lại trong vòng 6 tháng (ở 1 booking khác, sau này) không tính lại — kể cả khi khách quay lại
nhiều lần liên tiếp trong nhiều tháng, miễn mỗi khoảng cách giữa 2 lần liên tiếp đều < 6 tháng thì
chỉ tính bán chéo đúng 1 lần cho cả chuỗi (`cus_bl_paid_order`/`is_line_over_6_months_in_bl` vẫn
tính theo trình tự **toàn bộ lịch sử khách hàng** trong BL đó, không giới hạn theo từng booking —
việc "lan" nhãn sang các dòng khác chỉ xảy ra **trong phạm vi 1 booking**).
