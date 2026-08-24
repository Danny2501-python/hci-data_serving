# `func_stag_crm_line_ecosystem()` — stored procedure (KHÔNG phải dbt model)

> **Lưu ý phạm vi:** đây là 1 **PostgreSQL stored procedure** sống trực tiếp ở DB sandbox
> (schema `public`, không nêu host/port ở đây — xem `connection/` nội bộ nếu cần connect),
> **không nằm trong dbt project** `data_serving`, không có file `.sql` tương ứng trong repo.
> File này ghi lại logic để tiện đối chiếu với model dbt `stg_crm_line_ecosystem.sql` (xem
> `LOGIC.md` mục 3, đổi tên 2026-08-22 từ `stg_booking_xet_ban_cheo.sql`). **[2026-08-22]** model
> dbt đó đã được đồng bộ theo đúng logic mô tả trong file này (không còn là 2 pipeline tách biệt
> như trước) — 2 file vẫn không `ref()`/không share code với nhau (procedure sống ở DB, model
> sống trong dbt project), chỉ là logic nghiệp vụ được giữ khớp nhau chủ động. Đọc procedure bằng
> `pg_get_functiondef` ngày 2026-08-18, phiên bản procedure tại thời điểm đó — nếu procedure đổi
> tiếp sau ngày này, file này và `stg_crm_line_ecosystem.sql` có thể lệch lại, cần đọc lại
> procedure để đối chiếu.

## 1. Cơ chế chạy

`CALL public.func_stag_crm_line_ecosystem()` (chạy qua Airflow) — ghi thẳng vào bảng vật lý
`public.stag_crm_line_ecosystem` bằng `TRUNCATE` + `INSERT` bên trong 1 block có nhãn
`<<main_block>>` kèm `EXCEPTION WHEN OTHERS`:

- Nếu bất kỳ bước nào lỗi giữa chừng, Postgres tự `ROLLBACK TO SAVEPOINT` về đầu block →
  mọi `TRUNCATE`/`INSERT`/temp table của lần chạy lỗi đều bị hoàn tác, **bảng đích giữ nguyên
  dữ liệu của lần chạy thành công gần nhất**, không bị bỏ trống giữa chừng.
- Các `DROP TABLE IF EXISTS` trong `EXCEPTION` chỉ để phòng hờ (vô hại vì `IF EXISTS`).
- `RAISE` đẩy lại lỗi gốc ra ngoài → task Airflow vẫn fail đúng như bình thường (không bị nuốt lỗi).

## 2. Phạm vi

Toàn bộ procedure chỉ tính **`brand_etl = 1`** (Kangnam) — hardcode ở nhiều bước riêng lẻ
(bước 3, 3.5, 3.6...), không phải 1 filter chung ở đầu. Chỉ tính booking `type = 'opportunity'`
và thuộc tập "đã có tiền thành công" (tương đương `stg_booking_id_co_tien_tc` bên dbt).

## 3. Các bước

### Bước 1 — `tmp_booking_id_co_tien_tc`

Booking (`crm_id`) đã có tiền thành công: `crm_lead.stage_id = 4` và tổng
`stag_payment_transfer.payment` (group theo `crm_id, brand_etl`) > 0. Giống hệt logic
`stg_booking_id_co_tien_tc.sql` bên dbt.

### Bước 2 — `tmp_cline` (grain: 1 dòng dịch vụ)

Join `crm_line` + `crm_lead` + `stag_payment_transfer` (agg theo `clineid, brand_etl`) +
`view_stag_products` + `res_partner`. Cột `business_line` map từ `his_service_type` (CASE
`Surgery→PTTM`, `Spa/Laser/Card→Beauty & Spa`, `Odontology→Nha khoa`, `wellness→Wellness`,
`weight_loss→Weight Loss`, còn lại → `Khác`) — giống hệt CTE `cline` bên dbt.

> ⚠️ **Nghi vấn (chưa verify bằng data):** filter `WHERE cl.id IN (SELECT crm_id FROM
> tmp_booking_id_co_tien_tc)` chỉ so theo `cl.id`, không kèm `cl.brand_etl` — trong khi JOIN
> ngay phía trên match cả `cl.id = spt.crm_id AND cl.brand_etl = spt.brand_etl`. Nếu `crm_id`
> trùng số giữa các brand, 1 `crm_id` chỉ thật sự "có tiền thành công" ở brand khác có thể lọt
> qua filter này cho brand 1. Downstream có filter `brand_etl = 1` ở bước 3 nên rủi ro thực tế
> tuỳ vào việc `crm_id` có phải sequence global hay không.

### Bước 3 — `tmp_rnk_bl_cline`

Đánh số thứ tự cline: `cus_bl_cline_order` (theo `business_line, code_customer`),
`crm_cline_order` (theo `crm_id`), `cus_cline_order` (theo `code_customer`) — `ORDER BY
cline_created_date, cline_id` (kèm `cline_id` tie-break). Lọc `brand_etl = 1` ở bước này.

### Bước 3.5 — Nhóm dịch vụ chính (`tmp_nhom_dich_vu_chinh`) `[MỚI 2026-08-05]`

**Khác với dbt hiện tại** — dbt model `stg_booking_nhom_dich_vu_chinh.sql` đã đơn giản hóa
(2026-08-05) về **1 nguồn duy nhất** (`view_stag_products.product_group` của cline có `cln.id`
nhỏ nhất trong booking, bỏ hẳn 3 tầng ưu tiên — xem `LOGIC.md` mục 2). Procedure này **vẫn giữ
nguyên bản 3 tầng ưu tiên cũ** (không được đồng bộ theo lần đơn giản hóa đó):

1. **Tầng 1** (`tmp_uu_tien_1`): `crm_lead_product_category_rel` → `product_category.name`,
   lấy dòng có `ingestion_timestamp` sớm nhất mỗi `(crm_id, brand_etl)`.
2. **Tầng 2** (`tmp_uu_tien_2`): custom field `id=9794` ("Nhóm dịch vụ chính") trên
   `cs_deal_detail_api_v2` → `value_lable`, bóc mã trong ngoặc vuông (`"[KNP00001] PTTM MẮT"` →
   `"PTTM MẮT"`), mã khớp thẳng `product_category.code` (kèm `brand_etl`) để resolve
   `product_category_id`.
   > ⚠️ **Nghi vấn:** không có `ROW_NUMBER()`/`WHERE rn = 1` để dedup như tầng 1 và tầng 3 —
   > nếu `cs_custom_fields` có nhiều dòng khớp `value_id + custom_field_id = 9794`, 1 `crm_id`
   > có thể ra nhiều dòng cùng tầng 2, và bước gộp bên dưới (`ROW_NUMBER() ... ORDER BY
   > do_uu_tien`) sẽ chọn ngẫu nhiên giữa các dòng trùng đó → kết quả có thể không ổn định giữa
   > các lần chạy.
3. **Tầng 3** (fallback, `tmp_uu_tien_3`): `product_category` (từ `view_stag_products`) của
   cline sớm nhất (`cln.create_date` nhỏ nhất) trong booking.

`tmp_nhom_dich_vu_chinh` gộp 3 tầng (`UNION ALL`), `ROW_NUMBER() OVER (PARTITION BY crm_id,
brand_etl ORDER BY do_uu_tien)`, lấy `rn = 1` (tầng số nhỏ hơn thắng). `his_service_type`/
`business_line` resolve qua `tmp_ctg_service_type_map` (mode `his_service_type` theo
`product_ctg_id`) nếu không map được trực tiếp thì fallback regex trên text
`nhom_dich_vu_chinh` (`TẠO HÌNH|PHẪU THU|CHUYỂN GIỚI → PTTM`, `... DA|CHÀM|NÁM...→ Beauty & Spa`,
`NHA KHOA → Nha khoa`, còn lại → `Khác`).

> ⚠️ **Nghi vấn cao:** `tmp_ctg_service_type_map` được `GROUP BY product_ctg_id, his_service_type`
> **không kèm `brand_etl`**, và join lại (`csm.product_ctg_id = r.product_category_id`) cũng
> **không kèm `brand_etl`** — trong khi toàn bộ phần còn lại của procedure đều join
> `product_category`/`products` kèm `AND brand_etl = ...` như quy ước bắt buộc. Nếu
> `product_ctg_id` không phải sequence global duy nhất, mode `his_service_type` tính ra có thể
> bị lẫn dữ liệu category trùng ID từ brand khác.

### Bước 3.6 — `tmp_customer_main_bl` (`main_bl_customer`) `[ĐỔI 2026-08-05]`

`business_line` **ĐÃ RESOLVE qua 3 tầng ưu tiên ở bước 3.5** của **booking đầu tiên của KH**
(`crm_id` có `booking_report_date` sớm nhất, tie-break `cline_created_date`, `cline_id` của cline
sớm nhất trong booking đó) — **có thể `NULL`** nếu booking đầu tiên không resolve được nhóm dịch
vụ chính ở cả 3 tầng (khác hành vi cũ: theo `first_value` cline đầu tiên toàn lịch sử KH, luôn có
giá trị tối thiểu `'Khác'`).

Khi `main_bl_customer` là `NULL`, so sánh `business_line = main_bl_customer` ở CASE cuối luôn ra
`NULL` (không `TRUE`) → các dòng của KH đó luôn phải đi qua nhánh `bool_or()` để xác định
`is_cross_sale`, không còn được loại trừ sớm qua nhánh "thuộc main BL" nữa.

> 📌 **[Đã xử lý 2026-08-22]** trước đây file này ghi phần trên là "khác với dbt" (dbt còn dùng
> `first_value` cline đầu tiên) — ghi chú ngày 2026-08-05 trong `LOGIC.md` mục 3 nói procedure
> "vẫn dùng đúng logic đó" cũng đã lỗi thời so với bản source đọc ngày 2026-08-18. Đã sửa lại
> `LOGIC.md`, đồng thời **đồng bộ hẳn** `main_bl_customer`/`is_cross_sale` của model dbt
> `stg_crm_line_ecosystem.sql` (đổi tên từ `stg_booking_xet_ban_cheo.sql`) theo đúng logic 3 tầng
> mô tả ở trên — 2 bên **không còn khác nhau** ở điểm này nữa.

### Bước 4 — `tmp_paid_bl_cline`

Chỉ dòng có `cline_total_payment > 0`, đánh số `cus_bl_paid_order` theo `(business_line,
code_customer)`, `ORDER BY cline_payment_date, cline_id` — giống hệt CTE `paid_bl_cline` bên
dbt.

### Bước 5 — `tmp_labeling_1`

- `is_main_service` = `cus_cline_order = 1`; `is_main_service_bk` = `crm_cline_order = 1`
  (giữ để tương thích ngược).
- `is_line_over_6_months_in_bl`: so `cline_payment_date` hiện tại với dòng liền trước cùng BL
  đã có payment (`prev_pbc`, theo `cus_bl_paid_order - 1`) — không có dòng trước → `false`;
  cách nhau > 6 tháng → `true`. Giống hệt dbt.
- `main_bl_customer` / `source_main_bl`: lấy từ `tmp_customer_main_bl` (bước 3.6) — khác dbt
  như bảng so sánh ở trên.
- `main_bl_bk`: `first_value(business_line)` theo **từng booking** (`crm_id`) riêng — giữ lại
  để tham khảo, không dùng trong `is_cross_sale`. Tương đương `main_bl_bk` bên dbt.
- `main_product_category(_id)`: `first_value` theo **`code_customer`** (toàn lịch sử KH, mọi
  booking) — giống hệt dbt.

### Bước 7 — `tmp_main_bl_walkin`

Phiếu khám (`sh_medical_appointment_register_walkin`, `state = 'Completed'`) **đầu tiên** (theo
`service_date_start`, tie-break `w.id`) thuộc dịch vụ có `business_line = main_bl_customer` của
khách hàng: `main_bl_completed_date`, `main_bl_order_id` (`sale_order_id`), `main_bl_walkin_done`
(mã phiếu khám), `main_bl_booking_org` (mã booking gốc). Liên hệ: `walkin.booking_id =
crm_lead.id` → `sh_walkin_service_rel.walkin_id` → `service_id` → `view_stag_products.service_id`
(không phải `product_id`). Giống hệt CTE `main_bl_walkin` bên dbt — **chỉ tính cho main BL của
KH**, không phải cho từng dòng dịch vụ riêng lẻ.

### Bước 8 — `TRUNCATE` + `INSERT` (final), `is_cross_sale`

```
1. business_line = main_bl_customer
   OR main_bl_customer = 'Khác' OR business_line = 'Khác'          → false
2. source_main_bl = 'crm_lead_history' AND partner_create_date
   < '2025-08-01'                                                  → false
3. bool_or(
       coalesce(cline_total_payment, 0) > 0
       AND (cus_bl_paid_order = 1 OR is_line_over_6_months_in_bl)
   ) OVER (PARTITION BY crm_id, business_line)                     → true
4. else                                                             → false
```

Nhánh 3 giống hệt công thức bên dbt (`LOGIC.md` mục 3): chỉ cần **tồn tại** 1 dòng "kích hoạt"
(có payment thật, và là lần mua đầu tiên có payment của BL đó hoặc cách lần mua liền trước > 6
tháng) thì **mọi** dòng có payment > 0 của cùng BL trong cùng booking đều `is_cross_sale = true`.

**Nhánh 2** loại trừ hẳn các dòng của khách mà `main_bl_customer` resolve qua tầng 3 (fallback, độ
tin cậy thấp nhất) VÀ khách đó tạo tài khoản trước 2025-08-01 — tránh false positive cho nhóm
khách cũ mà dữ liệu 3-tầng-ưu-tiên không đủ tin cậy. **[2026-08-22]** model dbt
`stg_crm_line_ecosystem.sql` cũng đã có nhánh này (đồng bộ theo procedure).

`mbw.main_bl_completed_date`/`main_bl_order_id`/`main_bl_walkin_done`/`main_bl_booking_org`
được SELECT ra bảng đích nhưng **không dùng để chặn `is_cross_sale`** — giống cách dbt đang làm
(ghi chú "bỏ theo yêu cầu 2026-08-03" trong `LOGIC.md` mục 3).

## 4. Đề xuất đang thảo luận — CHƯA DEPLOY

*(cập nhật 2026-08-22, chưa áp dụng vào DB)* Đang bàn thêm điều kiện: 1 dòng dịch vụ chỉ được
tính bán chéo nếu **chính dòng đó** có ít nhất 1 phiếu khám (`sh_medical_appointment_register_walkin`,
`state = 'Completed'`) khớp theo `service_id` (của product trên dòng đó, qua
`view_stag_products.service_id`) **trong cùng booking** (`w.booking_id = cln.crm_id`) — khác với
`tmp_main_bl_walkin` ở bước 7 vốn chỉ tính phiếu khám Completed đầu tiên cho **main BL của cả
KH**, không phải cho từng dòng dịch vụ. Thiết kế: thêm bảng tạm
`tmp_service_walkin_completed` (crm_id, service_id, brand_etl) trước bước 2, join vào `tmp_cline`
lấy cờ `has_completed_walkin`, và thêm 1 nhánh `WHEN NOT has_completed_walkin THEN false` vào
CASE `is_cross_sale` ở bước 8 (trước nhánh `bool_or`), áp **ở mức từng dòng output**, không đổi
điều kiện "kích hoạt" của cả nhóm.
