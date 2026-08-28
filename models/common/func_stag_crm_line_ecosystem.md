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

## 4. `has_completed_walkin` — điều kiện tiên quyết theo từng dòng dịch vụ `[ĐÃ DEPLOY]`

**[Cập nhật 2026-08-26]** Mục này trước đây ghi "đề xuất đang thảo luận — CHƯA DEPLOY" (cập nhật
2026-08-22) — đã **kiểm tra lại definition thật trên sandbox** (`pg_get_functiondef`, 2026-08-26)
và xác nhận đề xuất **đã được deploy**, đúng như thiết kế mô tả trước đó:

- **Bước 1.5 (mới, chèn trước bước 2)** — `tmp_service_walkin_completed`: tập
  `(crm_id, service_id, brand_etl)` — `booking_id` của phiếu khám
  (`sh_medical_appointment_register_walkin`, `state = 'Completed'`) join `sh_walkin_service_rel`
  lấy `service_id`, giới hạn trong các `crm_id` đã "có tiền thành công"
  (`tmp_booking_id_co_tien_tc`).
- **`tmp_cline`**: join thêm `tmp_service_walkin_completed` (theo `crm_id = booking_id`,
  `service_id` khớp `view_stag_products.service_id` của product trên dòng đó, kèm `brand_etl`) →
  cột `has_completed_walkin` (**boolean**) = dòng dịch vụ này, **trong cùng booking**, đã có ít
  nhất 1 phiếu khám Completed khớp đúng `service_id` hay chưa.
- **CASE `is_cross_sale` (bước 8)**: thêm nhánh `WHEN NOT has_completed_walkin THEN false` —
  chèn **trước** nhánh `bool_or(...)`, sau 2 nhánh cũ (`business_line = main_bl_customer`/`Khác` và
  `source_main_bl = 'crm_lead_history' AND partner_create_date < 2025-08-01`) — áp ở mức từng dòng
  output, không đổi điều kiện "kích hoạt" của cả nhóm (bool_or vẫn tính như cũ).

> ⚠️ **Khác với những gì bảng output thể hiện ra ngoài:** `has_completed_walkin` chỉ là **cờ
> boolean tồn tại** (có/không), **không giữ lại ngày hoàn thành** (`service_date_start`) của phiếu
> khám đó, và **không được SELECT ra bảng vật lý** `public.stag_crm_line_ecosystem` (đã kiểm tra
> đủ 36 cột thật của bảng — không có cột này) — chỉ dùng nội bộ trong procedure để tính
> `is_cross_sale`. Khác với `main_bl_completed_date` (bước 7, cột có thật trong bảng output) vốn là
> 1 **ngày** nhưng chỉ tính cho **main BL của cả khách hàng**, không phải cho từng dòng/từng
> `business_line` riêng lẻ. Xem mục 5 — đang bổ sung cột ngày hoàn thành đầu tiên theo từng dòng
> dịch vụ (`line_completed_date`), sẽ tái dùng `tmp_service_walkin_completed` ở đây.

## 5. Cột `cline_walkin_finish_date` (trước đây `line_walkin_finish_date`) — ngày hoàn thành đầu tiên theo từng dòng dịch vụ

*(chốt thiết kế 2026-08-26, theo yêu cầu)* Bổ sung 1 cột **ngày** (khác `has_completed_walkin` ở
mục 4 vốn chỉ là cờ boolean) ghi nhận **ngày sớm nhất của phiếu khám khớp đúng dòng dịch vụ đó**,
tái dùng `tmp_service_walkin_completed` (mục 4), mở rộng thêm `MIN(service_date_start)`.

- **Tên cột**: `cline_walkin_finish_date` (đổi tên 2026-08-27, trước đó là `line_walkin_finish_date`
  — xem mục 6).
- **Phạm vi tính**: trong cùng booking (`crm_id`) — giống hệt phạm vi của `has_completed_walkin`,
  KHÔNG gộp theo toàn lịch sử khách hàng (khác cách `main_bl_completed_date` ở mục "Bước 7" đang
  tính cho main BL).
- **`has_completed_walkin`** giờ tương đương `cline_walkin_finish_date IS NOT NULL` — vẫn giữ tính
  cả 2 để rõ ý ở nơi dùng (procedure) / không bắt buộc bên dbt (dbt tính trực tiếp
  `cline_walkin_finish_date IS NOT NULL` làm `has_completed_walkin`, xem `LOGIC.md`).

### Trạng thái thực thi (2026-08-26, cột `line_walkin_finish_date` gốc)

- ✅ **dbt** (`stg_crm_line_ecosystem.sql`): đã sửa xong — thêm CTE `service_walkin_completed`,
  cột `line_walkin_finish_date`/`has_completed_walkin` trong `cline`, và gate
  `WHEN NOT has_completed_walkin THEN false` trong `is_cross_sale` (đồng bộ luôn gate ở mục 4 mà
  trước đó dbt còn thiếu). Xem `LOGIC.md` mục 3.
- ✅ **Sandbox** (`func_stag_crm_line_ecosystem()` + bảng vật lý `stag_crm_line_ecosystem`): **đã
  thực thi** (`ALTER TABLE ADD COLUMN line_walkin_finish_date timestamp without time zone` +
  `CREATE OR REPLACE PROCEDURE`). Đã kiểm tra lại bằng `pg_get_functiondef` + liệt kê cột thật của
  bảng (2026-08-26): cột `line_walkin_finish_date` có mặt, đúng vị trí cuối bảng (cột 37/37), khớp
  100% thiết kế — `tmp_service_walkin_completed` đã đổi `DISTINCT` → `GROUP BY` +
  `MIN(service_date_start)`, `tmp_cline` join lấy thêm cột này, `INSERT` cuối đã thêm
  `lb.line_walkin_finish_date`. **dbt và sandbox hiện đã khớp nhau hoàn toàn** ở cột này.

## 6. Đổi tên + sửa timezone/điều kiện `state` `[2026-08-27]`

Sau khi verify data thật (mục 5), phát hiện 2 vấn đề + 1 yêu cầu đổi tên:

1. **Đổi tên cột**: `line_walkin_finish_date` → `cline_walkin_finish_date` (rõ nghĩa "theo từng
   cline/dòng dịch vụ", tránh nhầm với các cột "line" khác đang mang nghĩa business_line).
2. **+7h cho `service_date_start`**: bảng `sh_medical_appointment_register_walkin` lưu UTC — cột
   này trước đó bị sót (khác `booking_report_date`/`cline_created_date`/`partner_create_date` đã
   +7h từ trước). Áp dụng ở **cả 2 chỗ** dùng `service_date_start`: `tmp_service_walkin_completed`
   (→ `cline_walkin_finish_date`) VÀ `tmp_main_bl_walkin_ranked` bước 7 (→ `main_bl_completed_date`).
3. **Bỏ điều kiện `w.state = 'Completed'`**, chỉ giữ `w.service_date_start IS NOT NULL` — cover
   nhiều trường hợp hợp lệ hơn, không giới hạn đúng state `'Completed'`. Áp dụng ở **cả 2 chỗ**
   trên. Tên `has_completed_walkin`/`tmp_service_walkin_completed`/`main_bl_completed_date` **giữ
   nguyên** dù không còn lọc theo state Completed nữa (cân nhắc đổi tên ở đợt sau nếu gây hiểu nhầm).

### Trạng thái thực thi (2026-08-27)

- ✅ **dbt** (`stg_crm_line_ecosystem.sql`): đã sửa xong cả 3 điểm trên.
- ✅ **Sandbox**: **[Cập nhật 2026-08-28]** đã xác nhận **thực thi rồi** — đọc lại
  `pg_get_functiondef` thật ngày 2026-08-28 (không chỉ tin theo trạng thái ghi trong file này, vốn
  đang ghi "CHƯA thực thi" nhầm) và cột thật của bảng `stag_crm_line_ecosystem` (cột 37/37 tên
  đúng `cline_walkin_finish_date`) — cả 3 điểm (đổi tên cột, +7h, bỏ `state='Completed'`) đều đã
  khớp trên procedure sống. Mục "Script cho sandbox" bên dưới **giữ lại để tham khảo lịch sử**,
  không cần chạy lại.

> ⚠️ **[Phát hiện 2026-08-28]** Khi đọc lại `pg_get_functiondef` để verify mục trên, phát hiện
> **Bước 1** (`tmp_booking_id_co_tien_tc`) trên procedure sống **đã khác hẳn** mô tả ở mục "Bước 1"
> phía trên: bản sống hiện lọc `cl.brand_etl > 0 AND cl.type_crm_id <> 1` (không còn `stage_id = 4`
> / `HAVING SUM(payment) > 0`), trong khi mục "Bước 1" ở trên và `stg_booking_id_co_tien_tc.sql`
> bên dbt vẫn theo logic cũ. Đây là 1 lệch tài liệu/lệch dbt riêng, **không liên quan** đến fix
> orphan ở mục 7 bên dưới — chưa xử lý, cần xác nhận thêm trước khi sửa.

### Script cho sandbox (chạy tay, theo thứ tự)

```sql
-- 1) Đổi tên cột vật lý (INSERT cuối procedure dùng positional match, không cần đổi thứ tự)
ALTER TABLE public.stag_crm_line_ecosystem
    RENAME COLUMN line_walkin_finish_date TO cline_walkin_finish_date;

-- 2) Thay procedure — 4 chỗ đổi so với bản đang chạy: bước 1.5 (bỏ state='Completed', +7h, đổi
-- tên alias), tmp_cline (đổi tên cột tham chiếu), bước 7/tmp_main_bl_walkin_ranked (bỏ
-- state='Completed', +7h), và INSERT cuối (đổi tên cột tham chiếu).
CREATE OR REPLACE PROCEDURE public.func_stag_crm_line_ecosystem()
 LANGUAGE plpgsql
AS $procedure$
BEGIN
    <<main_block>>
    BEGIN
    -- Bước 1: booking đã có tiền thành công
    DROP TABLE IF EXISTS tmp_booking_id_co_tien_tc;
    CREATE TEMP TABLE tmp_booking_id_co_tien_tc AS
        SELECT spt.crm_id, spt.brand_etl, SUM(spt.payment) AS total_payment
        FROM "staging_sci"."public"."stag_payment_transfer" spt
            LEFT JOIN "staging_sci"."public"."crm_lead" cl ON cl.id = spt.crm_id AND cl.brand_etl = spt.brand_etl
        WHERE cl.stage_id = 4
        GROUP BY spt.crm_id, spt.brand_etl
        HAVING SUM(spt.payment) > 0;
    -- Bước 1.5 [ĐỔI 2026-08-27]: bỏ state='Completed' (chỉ giữ service_date_start IS NOT NULL),
    -- +7h cho service_date_start (bảng gốc lưu UTC), đổi tên cột -> cline_walkin_finish_date.
    DROP TABLE IF EXISTS tmp_service_walkin_completed;
    CREATE TEMP TABLE tmp_service_walkin_completed AS
    SELECT w.booking_id AS crm_id, wsr.service_id, w.brand_etl,
        MIN(w.service_date_start + interval '7 hours') AS cline_walkin_finish_date
    FROM "staging_sci"."public"."sh_medical_appointment_register_walkin" w
        INNER JOIN "staging_sci"."public"."sh_walkin_service_rel" wsr
            ON wsr.walkin_id = w.id AND wsr.brand_etl = w.brand_etl
    WHERE w.service_date_start IS NOT NULL
        AND w.booking_id IN (SELECT crm_id FROM tmp_booking_id_co_tien_tc)
    GROUP BY w.booking_id, wsr.service_id, w.brand_etl;
    -- Bước 2: cline (grain: 1 dòng dịch vụ)
    DROP TABLE IF EXISTS tmp_cline;
    CREATE TEMP TABLE tmp_cline AS
        SELECT
            cl.id AS crm_id,
            cl.name AS code_booking,
            cl.code_customer,
            cln.brand_etl,
            cln.id AS cline_id,
            cln.stage,
            cln.product_id AS product_id,
            sp.product AS cline_service_name,
            sp.product_category AS cline_product_category,
            sp.product_ctg_id AS cline_product_category_id,
            CASE
                WHEN cl.customer_come = 'yes' THEN cl.arrival_date + interval '7 hours'
                ELSE cl.booking_date + interval '7 hours'
            END AS booking_report_date,
            cln.create_date + interval '7 hours' AS cline_created_date,
            spt.payment_date AS cline_payment_date,
            spt.total_payment AS cline_total_payment,
            CASE
                WHEN sp.his_service_type = 'Surgery' THEN 'PTTM'
                WHEN sp.his_service_type IN ('Spa','Laser','Card') THEN 'Beauty & Spa'
                WHEN sp.his_service_type = 'Odontology' THEN 'Nha khoa'
                WHEN sp.his_service_type = 'wellness' THEN 'Wellness'
                WHEN sp.his_service_type = 'weight_loss' THEN 'Weight Loss'
                ELSE 'Khác'
            END AS business_line,
            rp.create_date + interval '7 hours' AS partner_create_date,
            (swc.crm_id IS NOT NULL) AS has_completed_walkin,
            swc.cline_walkin_finish_date                            -- [ĐỔI 2026-08-27] đổi tên
        FROM "staging_sci"."public"."crm_line" cln
            LEFT JOIN "staging_sci"."public"."crm_lead" cl ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
            LEFT JOIN (
                SELECT clineid, brand_etl, MIN(payment_date) AS payment_date, SUM(payment) AS total_payment
                FROM "staging_sci"."public"."stag_payment_transfer"
                GROUP BY clineid, brand_etl
            ) spt ON spt.clineid = cln.id AND spt.brand_etl = cln.brand_etl
            LEFT JOIN "staging_sci"."public"."view_stag_products" sp ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
            LEFT JOIN "staging_sci"."public"."res_partner" rp ON cl.partner_id = rp.id AND cl.brand_etl = rp.brand_etl
            LEFT JOIN tmp_service_walkin_completed swc
                ON swc.crm_id = cl.id AND swc.service_id = sp.service_id AND swc.brand_etl = cln.brand_etl
        WHERE cl.id IN (SELECT crm_id FROM tmp_booking_id_co_tien_tc)
            AND cl.type = 'opportunity';

    -- Bước 3: đánh số thứ tự cline (kèm cline_id tie-break cho ổn định)
    DROP TABLE IF EXISTS tmp_rnk_bl_cline;
    CREATE TEMP TABLE tmp_rnk_bl_cline AS
        SELECT cln.*,
            ROW_NUMBER() OVER (PARTITION BY cln.business_line, cln.code_customer ORDER BY cln.cline_created_date, cln.cline_id) AS cus_bl_cline_order,
            ROW_NUMBER() OVER (PARTITION BY cln.crm_id ORDER BY cln.cline_created_date, cln.cline_id) AS crm_cline_order,
            ROW_NUMBER() OVER (PARTITION BY cln.code_customer ORDER BY cln.cline_created_date, cln.cline_id) AS cus_cline_order
        FROM tmp_cline cln
        WHERE cln.brand_etl = 1;

    DROP TABLE IF EXISTS tmp_ctg_service_type_map;
    CREATE TEMP TABLE tmp_ctg_service_type_map AS
        SELECT product_ctg_id, his_service_type
        FROM (
            SELECT product_ctg_id, his_service_type,
                ROW_NUMBER() OVER (PARTITION BY product_ctg_id ORDER BY COUNT(*) DESC) AS rn
            FROM "staging_sci"."public"."stag_products"
            WHERE product_ctg_id IS NOT NULL
            GROUP BY product_ctg_id, his_service_type
        ) t
        WHERE rn = 1;

    DROP TABLE IF EXISTS tmp_uu_tien_1;
    CREATE TEMP TABLE tmp_uu_tien_1 AS
        SELECT rel.crm_id, rel.brand_etl, rel.nhom_dich_vu_chinh, rel.product_category_id, 1 AS do_uu_tien
        FROM (
            SELECT
                r.lead_id AS crm_id,
                r.brand_etl,
                pc.name AS nhom_dich_vu_chinh,
                r.product_category_id,
                ROW_NUMBER() OVER (PARTITION BY r.lead_id, r.brand_etl ORDER BY r.ingestion_timestamp ASC) AS rn
            FROM "staging_sci"."public"."crm_lead_product_category_rel" r
                LEFT JOIN "staging_sci"."public"."product_category" pc
                    ON pc.id = r.product_category_id AND pc.brand_etl = r.brand_etl
            WHERE r.product_category_id IS NOT NULL
                AND r.brand_etl = 1
                AND r.lead_id IN (SELECT DISTINCT crm_id FROM tmp_rnk_bl_cline)
        ) rel
        WHERE rel.rn = 1;

    DROP TABLE IF EXISTS tmp_uu_tien_2;
    CREATE TEMP TABLE tmp_uu_tien_2 AS
        SELECT
            cl.id AS crm_id,
            cl.brand_etl,
            CASE
                WHEN ccf.value_lable LIKE '%]%' THEN TRIM(SPLIT_PART(ccf.value_lable, ']', 2))
                ELSE TRIM(ccf.value_lable)
            END AS nhom_dich_vu_chinh,
            pc2.id AS product_category_id,
            2 AS do_uu_tien
        FROM "staging_sci"."public"."crm_lead" cl
            INNER JOIN "staging_sci"."public"."cs_deal_detail_api_v2" cda ON cda.id = cl.ticket_id
            CROSS JOIN LATERAL jsonb_array_elements(cda.custom_fields::jsonb) cf_elem
            LEFT JOIN "staging_sci"."public"."cs_custom_fields" ccf
                ON ccf.value_id = (cf_elem ->> 'value')
                AND ccf.custom_field_id = '9794'
            LEFT JOIN "staging_sci"."public"."product_category" pc2
                ON pc2.code = SPLIT_PART(TRIM(SPLIT_PART(ccf.value_lable, ']', 1)), '[', 2)
                AND pc2.brand_etl = cl.brand_etl
                AND ccf.value_lable LIKE '%]%'
        WHERE cf_elem ->> 'id' = '9794'
            AND ccf.value_lable IS NOT NULL
            AND cl.brand_etl = 1
            AND cl.id IN (SELECT DISTINCT crm_id FROM tmp_rnk_bl_cline);

    DROP TABLE IF EXISTS tmp_uu_tien_3;
    CREATE TEMP TABLE tmp_uu_tien_3 AS
        SELECT line.crm_id, line.brand_etl, line.nhom_dich_vu_chinh, line.product_category_id, 3 AS do_uu_tien
        FROM (
            SELECT
                cln.crm_id,
                cln.brand_etl,
                sp.product_category AS nhom_dich_vu_chinh,
                sp.product_ctg_id AS product_category_id,
                ROW_NUMBER() OVER (PARTITION BY cln.crm_id, cln.brand_etl ORDER BY cln.create_date) AS rn
            FROM "staging_sci"."public"."crm_line" cln
                LEFT JOIN "staging_sci"."public"."view_stag_products" sp
                    ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
            WHERE cln.brand_etl = 1
                AND cln.crm_id IN (SELECT DISTINCT crm_id FROM tmp_rnk_bl_cline)
        ) line
        WHERE line.rn = 1
            AND line.nhom_dich_vu_chinh IS NOT NULL;

    DROP TABLE IF EXISTS tmp_nhom_dich_vu_chinh;
    CREATE TEMP TABLE tmp_nhom_dich_vu_chinh AS
        SELECT
            r.crm_id,
            r.brand_etl,
            r.nhom_dich_vu_chinh,
            r.do_uu_tien AS nguon_uu_tien,
            r.source_main_bl,
            r.product_category_id,
            csm.his_service_type,
            CASE
                WHEN csm.his_service_type = 'Surgery' THEN 'PTTM'
                WHEN csm.his_service_type IN ('Spa','Laser','Card') THEN 'Beauty & Spa'
                WHEN csm.his_service_type = 'Odontology' THEN 'Nha khoa'
                WHEN csm.his_service_type = 'wellness' THEN 'Wellness'
                WHEN csm.his_service_type = 'weight_loss' THEN 'Weight Loss'
                WHEN r.nhom_dich_vu_chinh ~* 'TẠO HÌNH|PHẪU THU|CHUYỂN GIỚI' THEN 'PTTM'
                WHEN r.nhom_dich_vu_chinh ~* ' DA|CHÀM|NÁM|TÀN NHANG|BỚT|LASER|LÔNG|ĐỒI MỒI|BAN VÀNG|SẸO|XĂM|TRẺ HÓA|MASSAG' THEN 'Beauty & Spa'
                WHEN r.nhom_dich_vu_chinh ~* 'NHA KHOA' THEN 'Nha khoa'
                ELSE 'Khác'
            END AS business_line
        FROM (
            SELECT c.*,
                ROW_NUMBER() OVER (PARTITION BY c.crm_id, c.brand_etl ORDER BY c.do_uu_tien) AS rn
            FROM (
                SELECT 'crm_lead_main_pc' AS source_main_bl, * FROM tmp_uu_tien_1
                UNION ALL
                SELECT 'ticket' AS source_main_bl, * FROM tmp_uu_tien_2
                UNION ALL
                SELECT 'crm_lead_history' AS source_main_bl, t.* FROM tmp_uu_tien_3 t
            ) c
            WHERE c.nhom_dich_vu_chinh IS NOT NULL
        ) r
            LEFT JOIN tmp_ctg_service_type_map csm ON csm.product_ctg_id = r.product_category_id
        WHERE r.rn = 1;

    DROP TABLE IF EXISTS tmp_customer_main_bl;
    CREATE TEMP TABLE tmp_customer_main_bl AS
        SELECT
            cfb.code_customer,
            ndc.business_line AS main_bl_customer,
            ndc.source_main_bl
        FROM (
            SELECT crm_id, code_customer,
                ROW_NUMBER() OVER (
                    PARTITION BY code_customer
                    ORDER BY booking_report_date, cline_created_date, cline_id
                ) AS rn
            FROM tmp_rnk_bl_cline
        ) cfb
            LEFT JOIN tmp_nhom_dich_vu_chinh ndc
                ON ndc.crm_id = cfb.crm_id AND ndc.brand_etl = 1
        WHERE cfb.rn = 1;

    -- Bước 4: chỉ dòng có payment > 0, đánh số thứ tự riêng để tính khoảng cách 6 tháng.
    DROP TABLE IF EXISTS tmp_paid_bl_cline;
    CREATE TEMP TABLE tmp_paid_bl_cline AS
        SELECT
            cline_id,
            crm_id,
            code_booking,
            code_customer,
            business_line,
            cline_payment_date,
            ROW_NUMBER() OVER (PARTITION BY business_line, code_customer ORDER BY cline_payment_date, cline_id) AS cus_bl_paid_order
        FROM tmp_rnk_bl_cline
        WHERE coalesce(cline_total_payment, 0) > 0;

    -- Bước 5: gắn nhãn is_main_service / is_line_over_6_months_in_bl / main_bl_customer / main_product_category / prev_bl_*
    DROP TABLE IF EXISTS tmp_labeling_1;
    CREATE TEMP TABLE tmp_labeling_1 AS
        SELECT
            rbc.*,
            pbc.cus_bl_paid_order,
            (rbc.cus_cline_order = 1) AS is_main_service,
            (rbc.crm_cline_order = 1) AS is_main_service_bk,
            (CASE
                WHEN prev_pbc.cline_payment_date IS NULL THEN false
                ELSE rbc.cline_payment_date > prev_pbc.cline_payment_date + interval '6 months'
            END) AS is_line_over_6_months_in_bl,
            cmb.main_bl_customer,
            cmb.source_main_bl,
            first_value(rbc.business_line) OVER (PARTITION BY rbc.crm_id ORDER BY rbc.cline_created_date, rbc.cline_id) AS main_bl_bk,
            first_value(rbc.cline_product_category_id) OVER (PARTITION BY rbc.code_customer ORDER BY rbc.cline_created_date, rbc.cline_id) AS main_product_category_id,
            first_value(rbc.cline_product_category) OVER (PARTITION BY rbc.code_customer ORDER BY rbc.cline_created_date, rbc.cline_id) AS main_product_category,
            prev_pbc.cline_payment_date AS prev_bl_order_date,
            (date(rbc.cline_payment_date) - date(prev_pbc.cline_payment_date)) AS diff_date_order_bl,
            prev_pbc.crm_id AS prev_bl_crm_id,
            prev_pbc.code_booking AS prev_bl_booking
        FROM tmp_rnk_bl_cline rbc
            LEFT JOIN tmp_paid_bl_cline pbc ON pbc.cline_id = rbc.cline_id
            LEFT JOIN tmp_paid_bl_cline prev_pbc
                ON prev_pbc.cus_bl_paid_order = pbc.cus_bl_paid_order - 1
                AND prev_pbc.code_customer = pbc.code_customer
                AND prev_pbc.business_line = pbc.business_line
            LEFT JOIN tmp_customer_main_bl cmb ON cmb.code_customer = rbc.code_customer;

    -- Bước 7 [ĐỔI 2026-08-27]: bỏ state='Completed' (chỉ giữ service_date_start IS NOT NULL), +7h
    -- cho service_date_start.
    DROP TABLE IF EXISTS tmp_main_bl_walkin_ranked;
    CREATE TEMP TABLE tmp_main_bl_walkin_ranked AS
        SELECT
            cl.code_customer,
            (w.service_date_start + interval '7 hours') AS service_date_start,
            w.sale_order_id,
            w.name AS code_walkin,
            cl.name AS code_booking_org,
            ROW_NUMBER() OVER (
                PARTITION BY cl.code_customer
                ORDER BY w.service_date_start, w.id
            ) AS rn
        FROM tmp_customer_main_bl cmb
            INNER JOIN "staging_sci"."public"."crm_lead" cl
                ON cl.code_customer = cmb.code_customer AND cl.brand_etl = 1
            INNER JOIN "staging_sci"."public"."sh_medical_appointment_register_walkin" w
                ON w.booking_id = cl.id AND w.brand_etl = cl.brand_etl
            INNER JOIN "staging_sci"."public"."sh_walkin_service_rel" wsr
                ON wsr.walkin_id = w.id AND wsr.brand_etl = w.brand_etl
            INNER JOIN "staging_sci"."public"."view_stag_products" sp
                ON sp.service_id = wsr.service_id AND sp.brand_etl = w.brand_etl
        WHERE w.service_date_start IS NOT NULL
            AND cmb.main_bl_customer = CASE
                WHEN sp.his_service_type = 'Surgery' THEN 'PTTM'
                WHEN sp.his_service_type IN ('Spa','Laser','Card') THEN 'Beauty & Spa'
                WHEN sp.his_service_type = 'Odontology' THEN 'Nha khoa'
                WHEN sp.his_service_type = 'wellness' THEN 'Wellness'
                WHEN sp.his_service_type = 'weight_loss' THEN 'Weight Loss'
                ELSE 'Khác'
            END;

    DROP TABLE IF EXISTS tmp_main_bl_walkin;
    CREATE TEMP TABLE tmp_main_bl_walkin AS
        SELECT
            code_customer,
            service_date_start AS main_bl_completed_date,
            sale_order_id AS main_bl_order_id,
            code_walkin AS main_bl_walkin_done,
            code_booking_org AS main_bl_booking_org
        FROM tmp_main_bl_walkin_ranked
        WHERE rn = 1;

    -- Bước 8: TRUNCATE + INSERT vào bảng vật lý đích
    TRUNCATE TABLE public.stag_crm_line_ecosystem;

    INSERT INTO public.stag_crm_line_ecosystem
    SELECT
        lb.crm_id,
        lb.code_booking,
        lb.code_customer,
        lb.brand_etl,
        lb.cline_id,
        lb.stage,
        lb.product_id,
        lb.cline_service_name,
        lb.cline_product_category,
        lb.cline_product_category_id,
        lb.booking_report_date,
        lb.cline_created_date,
        lb.cline_payment_date,
        lb.cline_total_payment,
        lb.business_line,
        lb.cus_bl_cline_order,
        lb.crm_cline_order,
        lb.cus_cline_order,
        lb.cus_bl_paid_order,
        lb.is_main_service,
        lb.is_main_service_bk,
        lb.is_line_over_6_months_in_bl,
        lb.main_bl_customer,
        lb.main_bl_bk,
        lb.main_product_category_id,
        lb.main_product_category,
        lb.prev_bl_order_date,
        lb.diff_date_order_bl,
        lb.prev_bl_crm_id,
        lb.prev_bl_booking,
        mbw.main_bl_completed_date,
        mbw.main_bl_order_id,
        mbw.main_bl_walkin_done,
        mbw.main_bl_booking_org,
        CASE
            WHEN lb.business_line = lb.main_bl_customer OR lb.main_bl_customer = 'Khác' OR lb.business_line = 'Khác' THEN false
            WHEN lb.source_main_bl = 'crm_lead_history' AND lb.partner_create_date < '2025-08-01' THEN FALSE
            WHEN NOT lb.has_completed_walkin THEN false
            WHEN bool_or(
                    coalesce(lb.cline_total_payment, 0) > 0
                    AND (lb.cus_bl_paid_order = 1 OR lb.is_line_over_6_months_in_bl = true)
                 ) OVER (PARTITION BY lb.crm_id, lb.business_line)
                THEN true
            ELSE false
        END AS is_cross_sale,
        lb.source_main_bl,
        lb.cline_walkin_finish_date                                 -- [ĐỔI 2026-08-27] đổi tên
    FROM tmp_labeling_1 lb
        LEFT JOIN tmp_main_bl_walkin mbw ON mbw.code_customer = lb.code_customer;

    -- Dọn bảng tạm khi chạy thành công
    DROP TABLE IF EXISTS tmp_booking_id_co_tien_tc;
    DROP TABLE IF EXISTS tmp_service_walkin_completed;
    DROP TABLE IF EXISTS tmp_cline;
    DROP TABLE IF EXISTS tmp_rnk_bl_cline;
    DROP TABLE IF EXISTS tmp_ctg_service_type_map;
    DROP TABLE IF EXISTS tmp_uu_tien_1;
    DROP TABLE IF EXISTS tmp_uu_tien_2;
    DROP TABLE IF EXISTS tmp_uu_tien_3;
    DROP TABLE IF EXISTS tmp_nhom_dich_vu_chinh;
    DROP TABLE IF EXISTS tmp_customer_main_bl;
    DROP TABLE IF EXISTS tmp_paid_bl_cline;
    DROP TABLE IF EXISTS tmp_labeling_1;
    DROP TABLE IF EXISTS tmp_main_bl_walkin_ranked;
    DROP TABLE IF EXISTS tmp_main_bl_walkin;

    EXCEPTION WHEN OTHERS THEN
        DROP TABLE IF EXISTS tmp_booking_id_co_tien_tc;
        DROP TABLE IF EXISTS tmp_service_walkin_completed;
        DROP TABLE IF EXISTS tmp_cline;
        DROP TABLE IF EXISTS tmp_rnk_bl_cline;
        DROP TABLE IF EXISTS tmp_ctg_service_type_map;
        DROP TABLE IF EXISTS tmp_uu_tien_1;
        DROP TABLE IF EXISTS tmp_uu_tien_2;
        DROP TABLE IF EXISTS tmp_uu_tien_3;
        DROP TABLE IF EXISTS tmp_nhom_dich_vu_chinh;
        DROP TABLE IF EXISTS tmp_customer_main_bl;
        DROP TABLE IF EXISTS tmp_paid_bl_cline;
        DROP TABLE IF EXISTS tmp_labeling_1;
        DROP TABLE IF EXISTS tmp_main_bl_walkin_ranked;
        DROP TABLE IF EXISTS tmp_main_bl_walkin;
        RAISE;
    END main_block;
END;
$procedure$;
```

Sau khi chạy `CREATE OR REPLACE PROCEDURE`, cần `CALL public.func_stag_crm_line_ecosystem();` để bảng vật lý được tính lại với logic mới (TRUNCATE + INSERT nằm trong procedure, không tự chạy khi chỉ `CREATE OR REPLACE`).

## 7. Lọc dòng orphan trong `sh_walkin_service_rel` `[MỚI 2026-08-28]`

Phát hiện qua case thật `crm_id=2363791`/`cline_id=4277370` — xem `LOGIC.md` mục 3 (CTE
`service_walkin_completed`) và `knowledge.md` mục 9 để biết đầy đủ root cause + cách verify (đối
chiếu 75/75 dòng `snapshot_date IS NULL` trong `sh_walkin_service_rel` với DB `new_product`, xác
nhận 100% là dòng đã bị xóa/sửa ở nguồn nhưng chưa được ETL dọn ở target).

**Fix:** thêm `AND wsr.snapshot_date IS NOT NULL` ở **cả 2 chỗ** procedure join
`sh_walkin_service_rel`: bước 1.5 (`tmp_service_walkin_completed`) và bước 7
(`tmp_main_bl_walkin_ranked`). **Không đụng Bước 1** (giữ nguyên logic `brand_etl > 0 AND
type_crm_id <> 1` đang chạy thật — xem cảnh báo lệch tài liệu ở trên, xử lý riêng, không gộp vào
đây).

### Trạng thái thực thi (2026-08-28)

- ✅ **dbt** (`stg_crm_line_ecosystem.sql`): đã sửa xong — thêm `wsr.snapshot_date IS NOT NULL` ở
  CTE `service_walkin_completed` và `main_bl_walkin_ranked`.
- ⏳ **Sandbox**: **CHƯA thực thi** — script đầy đủ bên dưới (dựa đúng trên bản `pg_get_functiondef`
  đọc ngày 2026-08-28, chỉ thêm 2 dòng filter, không đổi gì khác kể cả Bước 1), anh chạy tay.

### Script cho sandbox (chạy tay)

```sql
CREATE OR REPLACE PROCEDURE public.func_stag_crm_line_ecosystem()
 LANGUAGE plpgsql
AS $procedure$
BEGIN
    <<main_block>>
    BEGIN
    -- Bước 1: booking đã có tiền thành công (GIỮ NGUYÊN bản sống hiện tại — xem cảnh báo lệch tài
    -- liệu ở mục 6, không sửa ở đây)
    DROP TABLE IF EXISTS tmp_booking_id_co_tien_tc;
    CREATE TEMP TABLE tmp_booking_id_co_tien_tc AS
        SELECT cl.id AS crm_id, cl.brand_etl, SUM(spt.payment) AS total_payment
		FROM "staging_sci"."public"."crm_lead" cl
		    LEFT JOIN "staging_sci"."public"."stag_payment_transfer" spt
		        ON spt.crm_id = cl.id AND spt.brand_etl = cl.brand_etl
		WHERE cl.brand_etl > 0 AND cl.type_crm_id <> 1
		GROUP BY cl.id, cl.brand_etl ;
    -- Bước 1.5 [ĐỔI 2026-08-27]: bỏ state='Completed' (chỉ giữ service_date_start IS NOT NULL),
    -- +7h cho service_date_start (bảng gốc lưu UTC), đổi tên cột -> cline_walkin_finish_date.
    -- [MỚI 2026-08-28]: thêm wsr.snapshot_date IS NOT NULL — loại dòng orphan trong
    -- sh_walkin_service_rel (xem knowledge.md mục 9).
    DROP TABLE IF EXISTS tmp_service_walkin_completed;
    CREATE TEMP TABLE tmp_service_walkin_completed AS
    SELECT w.booking_id AS crm_id, wsr.service_id, w.brand_etl,
        MIN(w.service_date_start + interval '7 hours') AS cline_walkin_finish_date
    FROM "staging_sci"."public"."sh_medical_appointment_register_walkin" w
        INNER JOIN "staging_sci"."public"."sh_walkin_service_rel" wsr
            ON wsr.walkin_id = w.id AND wsr.brand_etl = w.brand_etl
    WHERE w.service_date_start IS NOT NULL
        AND wsr.snapshot_date IS NOT NULL
        AND w.booking_id IN (SELECT crm_id FROM tmp_booking_id_co_tien_tc)
    GROUP BY w.booking_id, wsr.service_id, w.brand_etl;
    -- Bước 2: cline (grain: 1 dòng dịch vụ)
    DROP TABLE IF EXISTS tmp_cline;
    CREATE TEMP TABLE tmp_cline AS
        SELECT
            cl.id AS crm_id,
            cl.name AS code_booking,
            cl.code_customer,
            cln.brand_etl,
            cln.id AS cline_id,
            cln.stage,
            cln.product_id AS product_id,
            sp.product AS cline_service_name,
            sp.product_category AS cline_product_category,
            sp.product_ctg_id AS cline_product_category_id,
            CASE
                WHEN cl.customer_come = 'yes' THEN cl.arrival_date + interval '7 hours'
                ELSE cl.booking_date + interval '7 hours'
            END AS booking_report_date,
            cln.create_date + interval '7 hours' AS cline_created_date,
            spt.payment_date AS cline_payment_date,
            spt.total_payment AS cline_total_payment,
            CASE
                WHEN sp.his_service_type = 'Surgery' THEN 'PTTM'
                WHEN sp.his_service_type IN ('Spa','Laser','Card') THEN 'Beauty & Spa'
                WHEN sp.his_service_type = 'Odontology' THEN 'Nha khoa'
                WHEN sp.his_service_type = 'wellness' THEN 'Wellness'
                WHEN sp.his_service_type = 'weight_loss' THEN 'Weight Loss'
                ELSE 'Khác'
            END AS business_line,
            rp.create_date + interval '7 hours' AS partner_create_date,
            (swc.crm_id IS NOT NULL) AS has_completed_walkin,
            swc.cline_walkin_finish_date
        FROM "staging_sci"."public"."crm_line" cln
            LEFT JOIN "staging_sci"."public"."crm_lead" cl ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
            LEFT JOIN (
                SELECT clineid, brand_etl, MIN(payment_date) AS payment_date, SUM(payment) AS total_payment
                FROM "staging_sci"."public"."stag_payment_transfer"
                GROUP BY clineid, brand_etl
            ) spt ON spt.clineid = cln.id AND spt.brand_etl = cln.brand_etl
            LEFT JOIN "staging_sci"."public"."view_stag_products" sp ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
            LEFT JOIN "staging_sci"."public"."res_partner" rp ON cl.partner_id = rp.id AND cl.brand_etl = rp.brand_etl
            LEFT JOIN tmp_service_walkin_completed swc
                ON swc.crm_id = cl.id AND swc.service_id = sp.service_id AND swc.brand_etl = cln.brand_etl
        WHERE cl.id IN (SELECT crm_id FROM tmp_booking_id_co_tien_tc)
            AND cl.type = 'opportunity';

    -- Bước 3: đánh số thứ tự cline (kèm cline_id tie-break cho ổn định)
    DROP TABLE IF EXISTS tmp_rnk_bl_cline;
    CREATE TEMP TABLE tmp_rnk_bl_cline AS
        SELECT cln.*,
            ROW_NUMBER() OVER (PARTITION BY cln.business_line, cln.code_customer ORDER BY cln.cline_created_date, cln.cline_id) AS cus_bl_cline_order,
            ROW_NUMBER() OVER (PARTITION BY cln.crm_id ORDER BY cln.cline_created_date, cln.cline_id) AS crm_cline_order,
            ROW_NUMBER() OVER (PARTITION BY cln.code_customer ORDER BY cln.cline_created_date, cln.cline_id) AS cus_cline_order
        FROM tmp_cline cln
        WHERE cln.brand_etl = 1;

    DROP TABLE IF EXISTS tmp_ctg_service_type_map;
    CREATE TEMP TABLE tmp_ctg_service_type_map AS
        SELECT product_ctg_id, his_service_type
        FROM (
            SELECT product_ctg_id, his_service_type,
                ROW_NUMBER() OVER (PARTITION BY product_ctg_id ORDER BY COUNT(*) DESC) AS rn
            FROM "staging_sci"."public"."stag_products"
            WHERE product_ctg_id IS NOT NULL
            GROUP BY product_ctg_id, his_service_type
        ) t
        WHERE rn = 1;

    DROP TABLE IF EXISTS tmp_uu_tien_1;
    CREATE TEMP TABLE tmp_uu_tien_1 AS
        SELECT rel.crm_id, rel.brand_etl, rel.nhom_dich_vu_chinh, rel.product_category_id, 1 AS do_uu_tien
        FROM (
            SELECT
                r.lead_id AS crm_id,
                r.brand_etl,
                pc.name AS nhom_dich_vu_chinh,
                r.product_category_id,
                ROW_NUMBER() OVER (PARTITION BY r.lead_id, r.brand_etl ORDER BY r.ingestion_timestamp ASC) AS rn
            FROM "staging_sci"."public"."crm_lead_product_category_rel" r
                LEFT JOIN "staging_sci"."public"."product_category" pc
                    ON pc.id = r.product_category_id AND pc.brand_etl = r.brand_etl
            WHERE r.product_category_id IS NOT NULL
                AND r.brand_etl = 1
                AND r.lead_id IN (SELECT DISTINCT crm_id FROM tmp_rnk_bl_cline)
        ) rel
        WHERE rel.rn = 1;

    DROP TABLE IF EXISTS tmp_uu_tien_2;
    CREATE TEMP TABLE tmp_uu_tien_2 AS
        SELECT
            cl.id AS crm_id,
            cl.brand_etl,
            CASE
                WHEN ccf.value_lable LIKE '%]%' THEN TRIM(SPLIT_PART(ccf.value_lable, ']', 2))
                ELSE TRIM(ccf.value_lable)
            END AS nhom_dich_vu_chinh,
            pc2.id AS product_category_id,
            2 AS do_uu_tien
        FROM "staging_sci"."public"."crm_lead" cl
            INNER JOIN "staging_sci"."public"."cs_deal_detail_api_v2" cda ON cda.id = cl.ticket_id
            CROSS JOIN LATERAL jsonb_array_elements(cda.custom_fields::jsonb) cf_elem
            LEFT JOIN "staging_sci"."public"."cs_custom_fields" ccf
                ON ccf.value_id = (cf_elem ->> 'value')
                AND ccf.custom_field_id = '9794'
            LEFT JOIN "staging_sci"."public"."product_category" pc2
                ON pc2.code = SPLIT_PART(TRIM(SPLIT_PART(ccf.value_lable, ']', 1)), '[', 2)
                AND pc2.brand_etl = cl.brand_etl
                AND ccf.value_lable LIKE '%]%'
        WHERE cf_elem ->> 'id' = '9794'
            AND ccf.value_lable IS NOT NULL
            AND cl.brand_etl = 1
            AND cl.id IN (SELECT DISTINCT crm_id FROM tmp_rnk_bl_cline);

    DROP TABLE IF EXISTS tmp_uu_tien_3;
    CREATE TEMP TABLE tmp_uu_tien_3 AS
        SELECT line.crm_id, line.brand_etl, line.nhom_dich_vu_chinh, line.product_category_id, 3 AS do_uu_tien
        FROM (
            SELECT
                cln.crm_id,
                cln.brand_etl,
                sp.product_category AS nhom_dich_vu_chinh,
                sp.product_ctg_id AS product_category_id,
                ROW_NUMBER() OVER (PARTITION BY cln.crm_id, cln.brand_etl ORDER BY cln.create_date) AS rn
            FROM "staging_sci"."public"."crm_line" cln
                LEFT JOIN "staging_sci"."public"."view_stag_products" sp
                    ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
            WHERE cln.brand_etl = 1
                AND cln.crm_id IN (SELECT DISTINCT crm_id FROM tmp_rnk_bl_cline)
        ) line
        WHERE line.rn = 1
            AND line.nhom_dich_vu_chinh IS NOT NULL;

    DROP TABLE IF EXISTS tmp_nhom_dich_vu_chinh;
    CREATE TEMP TABLE tmp_nhom_dich_vu_chinh AS
        SELECT
            r.crm_id,
            r.brand_etl,
            r.nhom_dich_vu_chinh,
            r.do_uu_tien AS nguon_uu_tien,
            r.source_main_bl,
            r.product_category_id,
            csm.his_service_type,
            CASE
                WHEN csm.his_service_type = 'Surgery' THEN 'PTTM'
                WHEN csm.his_service_type IN ('Spa','Laser','Card') THEN 'Beauty & Spa'
                WHEN csm.his_service_type = 'Odontology' THEN 'Nha khoa'
                WHEN csm.his_service_type = 'wellness' THEN 'Wellness'
                WHEN csm.his_service_type = 'weight_loss' THEN 'Weight Loss'
                WHEN r.nhom_dich_vu_chinh ~* 'TẠO HÌNH|PHẪU THU|CHUYỂN GIỚI' THEN 'PTTM'
                WHEN r.nhom_dich_vu_chinh ~* ' DA|CHÀM|NÁM|TÀN NHANG|BỚT|LASER|LÔNG|ĐỒI MỒI|BAN VÀNG|SẸO|XĂM|TRẺ HÓA|MASSAG' THEN 'Beauty & Spa'
                WHEN r.nhom_dich_vu_chinh ~* 'NHA KHOA' THEN 'Nha khoa'
                ELSE 'Khác'
            END AS business_line
        FROM (
            SELECT c.*,
                ROW_NUMBER() OVER (PARTITION BY c.crm_id, c.brand_etl ORDER BY c.do_uu_tien) AS rn
            FROM (
                SELECT 'crm_lead_main_pc' AS source_main_bl, * FROM tmp_uu_tien_1
                UNION ALL
                SELECT 'ticket' AS source_main_bl, * FROM tmp_uu_tien_2
                UNION ALL
                SELECT 'crm_lead_history' AS source_main_bl, t.* FROM tmp_uu_tien_3 t
            ) c
            WHERE c.nhom_dich_vu_chinh IS NOT NULL
        ) r
            LEFT JOIN tmp_ctg_service_type_map csm ON csm.product_ctg_id = r.product_category_id
        WHERE r.rn = 1;

    DROP TABLE IF EXISTS tmp_customer_main_bl;
    CREATE TEMP TABLE tmp_customer_main_bl AS
        SELECT
            cfb.code_customer,
            ndc.business_line AS main_bl_customer,
            ndc.source_main_bl
        FROM (
            SELECT crm_id, code_customer,
                ROW_NUMBER() OVER (
                    PARTITION BY code_customer
                    ORDER BY booking_report_date, cline_created_date, cline_id
                ) AS rn
            FROM tmp_rnk_bl_cline
        ) cfb
            LEFT JOIN tmp_nhom_dich_vu_chinh ndc
                ON ndc.crm_id = cfb.crm_id AND ndc.brand_etl = 1
        WHERE cfb.rn = 1;

    -- Bước 4: chỉ dòng có payment > 0, đánh số thứ tự riêng để tính khoảng cách 6 tháng.
    DROP TABLE IF EXISTS tmp_paid_bl_cline;
    CREATE TEMP TABLE tmp_paid_bl_cline AS
        SELECT
            cline_id,
            crm_id,
            code_booking,
            code_customer,
            business_line,
            cline_payment_date,
            ROW_NUMBER() OVER (PARTITION BY business_line, code_customer ORDER BY cline_payment_date, cline_id) AS cus_bl_paid_order
        FROM tmp_rnk_bl_cline
        WHERE coalesce(cline_total_payment, 0) > 0;

    -- Bước 5: gắn nhãn is_main_service / is_line_over_6_months_in_bl / main_bl_customer / main_product_category / prev_bl_*
    DROP TABLE IF EXISTS tmp_labeling_1;
    CREATE TEMP TABLE tmp_labeling_1 AS
        SELECT
            rbc.*,
            pbc.cus_bl_paid_order,
            (rbc.cus_cline_order = 1) AS is_main_service,
            (rbc.crm_cline_order = 1) AS is_main_service_bk,
            (CASE
                WHEN prev_pbc.cline_payment_date IS NULL THEN false
                ELSE rbc.cline_payment_date > prev_pbc.cline_payment_date + interval '6 months'
            END) AS is_line_over_6_months_in_bl,
            cmb.main_bl_customer,
            cmb.source_main_bl,
            first_value(rbc.business_line) OVER (PARTITION BY rbc.crm_id ORDER BY rbc.cline_created_date, rbc.cline_id) AS main_bl_bk,
            first_value(rbc.cline_product_category_id) OVER (PARTITION BY rbc.code_customer ORDER BY rbc.cline_created_date, rbc.cline_id) AS main_product_category_id,
            first_value(rbc.cline_product_category) OVER (PARTITION BY rbc.code_customer ORDER BY rbc.cline_created_date, rbc.cline_id) AS main_product_category,
            prev_pbc.cline_payment_date AS prev_bl_order_date,
            (date(rbc.cline_payment_date) - date(prev_pbc.cline_payment_date)) AS diff_date_order_bl,
            prev_pbc.crm_id AS prev_bl_crm_id,
            prev_pbc.code_booking AS prev_bl_booking
        FROM tmp_rnk_bl_cline rbc
            LEFT JOIN tmp_paid_bl_cline pbc ON pbc.cline_id = rbc.cline_id
            LEFT JOIN tmp_paid_bl_cline prev_pbc
                ON prev_pbc.cus_bl_paid_order = pbc.cus_bl_paid_order - 1
                AND prev_pbc.code_customer = pbc.code_customer
                AND prev_pbc.business_line = pbc.business_line
            LEFT JOIN tmp_customer_main_bl cmb ON cmb.code_customer = rbc.code_customer;

    -- Bước 7 [ĐỔI 2026-08-27]: bỏ state='Completed' (chỉ giữ service_date_start IS NOT NULL), +7h
    -- cho service_date_start. [MỚI 2026-08-28]: thêm wsr.snapshot_date IS NOT NULL.
    DROP TABLE IF EXISTS tmp_main_bl_walkin_ranked;
    CREATE TEMP TABLE tmp_main_bl_walkin_ranked AS
        SELECT
            cl.code_customer,
            (w.service_date_start + interval '7 hours') AS service_date_start,
            w.sale_order_id,
            w.name AS code_walkin,
            cl.name AS code_booking_org,
            ROW_NUMBER() OVER (
                PARTITION BY cl.code_customer
                ORDER BY w.service_date_start, w.id
            ) AS rn
        FROM tmp_customer_main_bl cmb
            INNER JOIN "staging_sci"."public"."crm_lead" cl
                ON cl.code_customer = cmb.code_customer AND cl.brand_etl = 1
            INNER JOIN "staging_sci"."public"."sh_medical_appointment_register_walkin" w
                ON w.booking_id = cl.id AND w.brand_etl = cl.brand_etl
            INNER JOIN "staging_sci"."public"."sh_walkin_service_rel" wsr
                ON wsr.walkin_id = w.id AND wsr.brand_etl = w.brand_etl
            INNER JOIN "staging_sci"."public"."view_stag_products" sp
                ON sp.service_id = wsr.service_id AND sp.brand_etl = w.brand_etl
        WHERE w.service_date_start IS NOT NULL
            AND wsr.snapshot_date IS NOT NULL
            AND cmb.main_bl_customer = CASE
                WHEN sp.his_service_type = 'Surgery' THEN 'PTTM'
                WHEN sp.his_service_type IN ('Spa','Laser','Card') THEN 'Beauty & Spa'
                WHEN sp.his_service_type = 'Odontology' THEN 'Nha khoa'
                WHEN sp.his_service_type = 'wellness' THEN 'Wellness'
                WHEN sp.his_service_type = 'weight_loss' THEN 'Weight Loss'
                ELSE 'Khác'
            END;

    DROP TABLE IF EXISTS tmp_main_bl_walkin;
    CREATE TEMP TABLE tmp_main_bl_walkin AS
        SELECT
            code_customer,
            service_date_start AS main_bl_completed_date,
            sale_order_id AS main_bl_order_id,
            code_walkin AS main_bl_walkin_done,
            code_booking_org AS main_bl_booking_org
        FROM tmp_main_bl_walkin_ranked
        WHERE rn = 1;

    -- Bước 8: TRUNCATE + INSERT vào bảng vật lý đích
    TRUNCATE TABLE public.stag_crm_line_ecosystem;

    INSERT INTO public.stag_crm_line_ecosystem
    SELECT
        lb.crm_id,
        lb.code_booking,
        lb.code_customer,
        lb.brand_etl,
        lb.cline_id,
        lb.stage,
        lb.product_id,
        lb.cline_service_name,
        lb.cline_product_category,
        lb.cline_product_category_id,
        lb.booking_report_date,
        lb.cline_created_date,
        lb.cline_payment_date,
        lb.cline_total_payment,
        lb.business_line,
        lb.cus_bl_cline_order,
        lb.crm_cline_order,
        lb.cus_cline_order,
        lb.cus_bl_paid_order,
        lb.is_main_service,
        lb.is_main_service_bk,
        lb.is_line_over_6_months_in_bl,
        lb.main_bl_customer,
        lb.main_bl_bk,
        lb.main_product_category_id,
        lb.main_product_category,
        lb.prev_bl_order_date,
        lb.diff_date_order_bl,
        lb.prev_bl_crm_id,
        lb.prev_bl_booking,
        mbw.main_bl_completed_date,
        mbw.main_bl_order_id,
        mbw.main_bl_walkin_done,
        mbw.main_bl_booking_org,
        CASE
            WHEN lb.business_line = lb.main_bl_customer OR lb.main_bl_customer = 'Khác' OR lb.business_line = 'Khác' THEN false
            WHEN lb.source_main_bl = 'crm_lead_history' AND lb.partner_create_date < '2025-08-01' THEN FALSE
            WHEN NOT lb.has_completed_walkin THEN false
            WHEN bool_or(
                    coalesce(lb.cline_total_payment, 0) > 0
                    AND (lb.cus_bl_paid_order = 1 OR lb.is_line_over_6_months_in_bl = true)
                 ) OVER (PARTITION BY lb.crm_id, lb.business_line)
                THEN true
            ELSE false
        END AS is_cross_sale,
        lb.source_main_bl,
        lb.cline_walkin_finish_date
    FROM tmp_labeling_1 lb
        LEFT JOIN tmp_main_bl_walkin mbw ON mbw.code_customer = lb.code_customer;

    -- Dọn bảng tạm khi chạy thành công
    DROP TABLE IF EXISTS tmp_booking_id_co_tien_tc;
    DROP TABLE IF EXISTS tmp_service_walkin_completed;
    DROP TABLE IF EXISTS tmp_cline;
    DROP TABLE IF EXISTS tmp_rnk_bl_cline;
    DROP TABLE IF EXISTS tmp_ctg_service_type_map;
    DROP TABLE IF EXISTS tmp_uu_tien_1;
    DROP TABLE IF EXISTS tmp_uu_tien_2;
    DROP TABLE IF EXISTS tmp_uu_tien_3;
    DROP TABLE IF EXISTS tmp_nhom_dich_vu_chinh;
    DROP TABLE IF EXISTS tmp_customer_main_bl;
    DROP TABLE IF EXISTS tmp_paid_bl_cline;
    DROP TABLE IF EXISTS tmp_labeling_1;
    DROP TABLE IF EXISTS tmp_main_bl_walkin_ranked;
    DROP TABLE IF EXISTS tmp_main_bl_walkin;

    EXCEPTION WHEN OTHERS THEN
        DROP TABLE IF EXISTS tmp_booking_id_co_tien_tc;
        DROP TABLE IF EXISTS tmp_service_walkin_completed;
        DROP TABLE IF EXISTS tmp_cline;
        DROP TABLE IF EXISTS tmp_rnk_bl_cline;
        DROP TABLE IF EXISTS tmp_ctg_service_type_map;
        DROP TABLE IF EXISTS tmp_uu_tien_1;
        DROP TABLE IF EXISTS tmp_uu_tien_2;
        DROP TABLE IF EXISTS tmp_uu_tien_3;
        DROP TABLE IF EXISTS tmp_nhom_dich_vu_chinh;
        DROP TABLE IF EXISTS tmp_customer_main_bl;
        DROP TABLE IF EXISTS tmp_paid_bl_cline;
        DROP TABLE IF EXISTS tmp_labeling_1;
        DROP TABLE IF EXISTS tmp_main_bl_walkin_ranked;
        DROP TABLE IF EXISTS tmp_main_bl_walkin;
        RAISE;
    END main_block;
END;
$procedure$;
```

Sau khi chạy `CREATE OR REPLACE PROCEDURE`, cần `CALL public.func_stag_crm_line_ecosystem();` để bảng vật lý được tính lại với logic mới (TRUNCATE + INSERT nằm trong procedure, không tự chạy khi chỉ `CREATE OR REPLACE`).
