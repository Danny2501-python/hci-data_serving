# common — Logic nghiệp vụ

## 1. stg_booking_id_co_tien_tc.sql

Danh sách `crm_id` (booking) đã "có tiền thành công": `crm_lead.stage_id = 4` và tổng
`stag_payment_transfer.payment` (group theo `crm_id, brand_etl`) > 0. Dùng làm điều kiện lọc
đầu vào cho các model booking khác trong `common/`.

## 2. stg_booking_nhom_dich_vu_chinh.sql

**[Đã đổi 2026-08-05]** Xác định **nhóm dịch vụ chính của booking** (`crm_id`). Chỉ tính
`brand_etl = 1` (Kangnam). Đã khớp lại logic theo `view_stag_crm_lead_first_product_group` bên DB
sandbox (`staging_sci` — xem `knowledge.md` mục 8):

```sql
SELECT DISTINCT ON (cl.id)
    cl.id AS crm_id, cln.brand_etl,
    sp.product_group AS nhom_dich_vu_chinh,
    sp.product_ctg_id AS product_category_id,
    sp.his_service_type,
    <CASE business_line giống mục dưới>
FROM crm_line cln
    LEFT JOIN crm_lead cl ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
    LEFT JOIN view_stag_products sp ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
WHERE cln.brand_etl = 1
ORDER BY cl.id, cln.id
```

**1 nguồn duy nhất** — dòng dịch vụ (cline) có `cln.id` **nhỏ nhất** trong booking (không phải
`cline_created_date` sớm nhất). Bỏ hẳn 3 tầng ưu tiên cũ (`crm_lead_product_category_rel` / custom
field 9794 trên `cs_deal_detail_api_v2` / fallback cline theo `create_date`) — đã verify: mất
`crm_lead_product_category_rel`/custom field 9794 không ảnh hưởng độ chính xác so với sandbox
(sandbox cũng không dùng 2 nguồn này).

`nhom_dich_vu_chinh` giờ = **`view_stag_products.product_group`** — nhãn **đã phân nhóm sẵn**
(CASE WHEN bake trong view, xem `knowledge.md` mục 8): `SẢN PHẨM` / `BEAUTY & SPA` /
`PTTM HÀM MẶT` / `WELLNESS` / `BÉO ĐA CHUYÊN KHOA` / `PTTM MẮT` / `PTTM MŨI` / `CẤY MỠ` /
`PTTM NGỰC/MÔNG` / `DỊCH VỤ KHÁC` — **không còn** là category thô như bản trước.

`his_service_type`/`business_line` lấy **trực tiếp** từ đúng dòng `view_stag_products` đã join —
không cần join phụ sang `stag_products_dbt` theo `product_ctg_id`/mode như bản trước (đơn giản hơn
hẳn, vì giờ chỉ có 1 nguồn duy nhất, không còn tình huống 1 category ứng với nhiều
`his_service_type` khác nhau cần chọn mode). `business_line` map từ `his_service_type` giống hệt
CASE ở mục 3 bên dưới (`Surgery→PTTM`, `Spa/Laser/Card→Beauty & Spa`, `Odontology→Nha khoa`,
`wellness→Wellness`, `weight_loss→Weight Loss`, còn lại có `his_service_type`→`Khác`, không có
sản phẩm khớp→`NULL`).

Phạm vi `brand_etl = 1`: sandbox view không filter brand (tính mọi brand), model này vẫn giữ filter
`brand_etl = 1` theo đúng quy ước chung của `common/` — không phải sai lệch logic, chỉ thu hẹp
phạm vi tính toán.

## 3. stg_crm_line_ecosystem.sql (materialized = `view`)

**[Đổi tên 2026-08-22]** trước đây là `stg_booking_xet_ban_cheo.sql` — đổi tên cho khớp tên bảng
vật lý `public.stag_crm_line_ecosystem` mà stored procedure `func_stag_crm_line_ecosystem()`
(ngoài dbt project) ghi ra, vì từ bản này logic `main_bl_customer`/`is_cross_sale` đã đồng bộ theo
đúng procedure đó (xem `func_stag_crm_line_ecosystem.md`). Không đổi tên vật lý nào khác (view
`stg_crm_line_ecosystem` do dbt build ra vẫn là 1 thực thể độc lập, không phải bảng
`stag_crm_line_ecosystem` của procedure).

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
- `partner_create_date`: `res_partner.create_date` (join `crm_lead.partner_id = res_partner.id`,
  kèm `brand_etl`) — **[Mới 2026-08-22]**, dùng để loại trừ nhóm khách cũ ở quy tắc `is_cross_sale`
  bên dưới.

### CTE `ctg_service_type_map` / `uu_tien_1` / `uu_tien_2` / `uu_tien_3` / `nhom_dich_vu_chinh` — nhóm dịch vụ chính của booking `[Mới 2026-08-22]`

Port y hệt bước 3.5 của procedure `func_stag_crm_line_ecosystem()` (3 tầng ưu tiên: 1.
`crm_lead_product_category_rel` → `product_category.name`; 2. custom field `id=9794` trên
`cs_deal_detail_api_v2`; 3. fallback `product_category` của cline sớm nhất trong booking) — chi
tiết xem `func_stag_crm_line_ecosystem.md` mục Bước 3.5, **không lặp lại ở đây**. Chỉ dùng nội bộ
để resolve `main_bl_customer` bên dưới, **không** đụng/không thay `stg_booking_nhom_dich_vu_chinh.sql`
(model đó đã chủ động đơn giản hóa bỏ 3 tầng — xem mục 2 — và đang dùng chung với
`stg_dv_khach_hang_quan_tam`; 3 tầng ở đây là bản viết riêng, độc lập, chỉ tồn tại trong
`stg_crm_line_ecosystem.sql`).

> Cố tình port **y hệt** procedure kể cả 2 nghi vấn logic (chưa verify bằng data thật):
> `ctg_service_type_map` không group/join kèm `brand_etl`; `uu_tien_2` không có
> `ROW_NUMBER()`/dedup như tầng 1 và tầng 3 — để kết quả dbt khớp 100% với bảng vật lý
> `stag_crm_line_ecosystem`, không tự sửa.

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
- `main_bl_customer` **[Đổi 2026-08-22]**: không còn theo `first_value` cline đầu tiên — giờ lấy
  từ CTE `customer_main_bl` (`crm_id` có `booking_report_date` sớm nhất của khách, tie-break
  `cline_created_date`/`cline_id`; `business_line` của booking đó được resolve qua 3 tầng ưu tiên ở
  CTE `nhom_dich_vu_chinh` phía trên). **Có thể `NULL`** nếu booking đầu tiên không resolve được
  nhóm dịch vụ chính ở cả 3 tầng — khác hành vi cũ (luôn có giá trị, tối thiểu `'Khác'`). Khi
  `NULL`, so sánh `business_line = main_bl_customer` ở CASE `is_cross_sale` không bao giờ `TRUE`
  (`NULL = x` luôn `NULL`) → dòng đó luôn đi qua nhánh `bool_or()`.
- `source_main_bl` **[Mới 2026-08-22]**: tầng ưu tiên đã resolve ra `main_bl_customer`
  (`crm_lead_main_pc` / `ticket` / `crm_lead_history`) — dùng ở quy tắc `is_cross_sale` bên dưới để
  loại trừ nhóm khách cũ resolve qua tầng fallback.
- `main_bl_bk`: `first_value(business_line)` theo từng booking (`crm_id`) riêng (cline đầu tiên
  của booking đó) — **không dùng** trong `is_cross_sale`, chỉ giữ lại để tham khảo.

> **Lịch sử:** [2026-08-05] đã từng thử đổi `main_bl_customer` sang cách này rồi **revert lại**
> logic `first_value` gốc theo yêu cầu lúc đó, giữ tách biệt hoàn toàn với procedure
> `func_stag_crm_line_ecosystem()` để dễ đối chiếu 2 pipeline độc lập. **[2026-08-22] đã đổi lại
> lần nữa** — lần này đồng bộ hẳn theo đúng logic mới nhất của procedure (xem
> `func_stag_crm_line_ecosystem.md` mục Bước 3.6), không còn tách biệt 2 cách tính `main_bl_customer`
> như trước. Vẫn **không** `ref()` `stg_booking_nhom_dich_vu_chinh` — 3 tầng ưu tiên là CTE viết
> riêng trong chính model này (xem mục ngay phía trên).
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
1. business_line = main_bl_customer
   OR main_bl_customer = 'Khác' OR business_line = 'Khác'   → false (thuộc main BL, hoặc main BL/BL hiện tại chưa phân loại được)
2. source_main_bl = 'crm_lead_history'
   AND partner_create_date < '2025-08-01'                   → false  -- [Mới 2026-08-22]
3. EXISTS (trong cùng booking crm_id + cùng business_line) ít nhất 1 dòng khác thỏa:
       cline_total_payment > 0
       AND (cus_bl_paid_order = 1 OR is_line_over_6_months_in_bl = true)
   (tính bằng bool_or(...) OVER (PARTITION BY crm_id, business_line))
                                                             → true
4. else                                                     → false
```

Nhánh 1 và 3 giữ nguyên như trước. **Nhánh 2 là mới (2026-08-22)**, đồng bộ theo procedure: loại
trừ hẳn các dòng của khách mà `main_bl_customer` resolve qua tầng 3 (fallback, độ tin cậy thấp
nhất) VÀ khách đó tạo tài khoản (`res_partner.create_date`) trước 2025-08-01 — tránh false
positive cho nhóm khách cũ mà dữ liệu 3-tầng-ưu-tiên không đủ tin cậy.

`main_bl_completed_date IS NULL` **không còn** chặn `is_cross_sale` (bỏ theo yêu cầu 2026-08-03) —
cột này vẫn được SELECT ra (`mbw.main_bl_completed_date`) để tầng Tableau tự lọc nếu cần, nhưng bản
thân cờ `is_cross_sale` không phụ thuộc vào việc main BL đã "hoàn thành" (có walkin Completed) hay
chưa. Vd khách CUS712615: dòng Nha khoa đã trả 28.000.000, đủ điều kiện kích hoạt (lần mua đầu của
BL Nha khoa) → `is_cross_sale = true`, dù khách chưa có walkin PTTM (main BL) nào Completed.

Diễn giải: một booking (`crm_id`) được coi là "lần bán bán chéo" cho 1 business_line khác main BL
nếu nó chứa ít nhất 1 dòng dịch vụ "kích hoạt" — có payment thật, và (a) là lần mua có payment đầu
tiên của BL đó, hoặc (b) cách lần mua có payment liền trước của BL đó > 6 tháng. Khi booking đó đã
được kích hoạt, **toàn bộ** các dòng dịch vụ của cùng BL đó trong cùng booking đều được gắn
`is_cross_sale = true`, không chỉ riêng dòng kích hoạt và **không yêu cầu bản thân dòng đó đã có
payment** (kể cả payment = 0/NULL cũng được gắn true — lọc theo payment cho mục đích báo cáo là
việc của tầng Tableau, không phải của cờ `is_cross_sale` trong model này). Vd khách mua 2 dịch vụ
Beauty & Spa trong cùng 1 booking bán chéo, dù mới chỉ 1 dòng đã thanh toán → cả 2 dòng đều tính
`true`, kể cả dòng chưa trả tiền.

**Lưu ý:** điều kiện *xác định dòng nào là "dòng kích hoạt"* (`cus_bl_paid_order = 1` hoặc
`is_line_over_6_months_in_bl`) vẫn chỉ tính trên các dòng **đã có payment** (`paid_bl_cline` CTE
lọc `cline_total_payment > 0`) — vì thứ tự "lần mua đầu tiên"/khoảng cách 6 tháng chỉ có ý nghĩa
dựa trên giao dịch thật. Thay đổi ở đây chỉ là: một khi đã xác định được booking/BL có kích hoạt,
nhãn `true` áp cho MỌI dòng của BL đó trong booking, không giới hạn ở dòng đã trả tiền.

Mua lại trong vòng 6 tháng (ở 1 booking khác, sau này) không tính lại — kể cả khi khách quay lại
nhiều lần liên tiếp trong nhiều tháng, miễn mỗi khoảng cách giữa 2 lần liên tiếp đều < 6 tháng thì
chỉ tính bán chéo đúng 1 lần cho cả chuỗi (`cus_bl_paid_order`/`is_line_over_6_months_in_bl` vẫn
tính theo trình tự **toàn bộ lịch sử khách hàng** trong BL đó, không giới hạn theo từng booking —
việc "lan" nhãn sang các dòng khác chỉ xảy ra **trong phạm vi 1 booking**).
