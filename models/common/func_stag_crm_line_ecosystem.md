# `func_stag_crm_line_ecosystem()` — stored procedure (KHÔNG phải dbt model)

> **Lưu ý phạm vi:** đây là 1 **PostgreSQL stored procedure** sống trực tiếp ở DB sandbox
> (schema `public`, không nêu host/port ở đây — xem `connection/` nội bộ nếu cần connect),
> **không nằm trong dbt project** `data_serving`, không có file `.sql` tương ứng trong repo.
> File này ghi lại logic để tiện đối chiếu với model dbt `stg_crm_line_ecosystem.sql` (xem
> `LOGIC.md` mục 3, đổi tên 2026-08-22 từ `stg_booking_xet_ban_cheo.sql`). Đọc procedure bằng
> `pg_get_functiondef`: lần đầu 2026-08-18, cập nhật 2026-08-26/2026-08-27, và **đọc lại lần nữa
> ngày 2026-09-16** — lần đọc gần nhất phát hiện procedure đã đổi **nhiều hơn** những gì tài liệu
> này từng ghi (xem mục 7). **Nếu procedure đổi tiếp sau 2026-09-16, file này có thể lệch lại —
> luôn đọc lại bằng `pg_get_functiondef` trước khi tin tưởng tuyệt đối vào nội dung dưới đây,
> đừng suy đoán qua mô tả lời.**

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

**[Cập nhật 2026-09-16 — xem mục 7.1]** Trước đây mục này ghi "chỉ tính booking thuộc tập 'đã có
tiền thành công'" — không còn đúng. Bảng tạm vẫn tên `tmp_booking_id_co_tien_tc` nhưng điều kiện
bên trong đã đổi hẳn ý nghĩa, không còn lọc theo `stage_id`/tổng payment nữa (xem mục 7.1 để biết
điều kiện thật hiện tại). Điều duy nhất còn đúng như cũ:

- `cl.type = 'opportunity'` (lọc ở bước 2, `tmp_cline`).
- Tính riêng theo `brand_etl` — hardcode `brand_etl = 1` (Kangnam) ở nhiều bước riêng lẻ (bước 3,
  3.5, 3.6...), không phải 1 filter chung ở đầu.

## 3. Các bước

### Bước 1 — `tmp_booking_id_co_tien_tc`

**[Đổi ý nghĩa 2026-09-16 — xem mục 7.1]** Tên bảng tạm gợi ý "booking đã có tiền thành công"
nhưng điều kiện thật hiện tại **không còn kiểm tra điều đó** — xem mục 7.1 cho định nghĩa đầy đủ
đang chạy thật.

### Bước 1.4 — `tmp_wsr_last_snapshot` `[MỚI 2026-08-28, ghi nhận 2026-09-16]`

Xem mục 7.2.

### Bước 2 — `tmp_cline` (grain: 1 dòng dịch vụ)

Join `crm_line` + `crm_lead` + `stag_payment_transfer` (agg theo `clineid, brand_etl`) +
`view_stag_products` + `res_partner`. Cột `business_line` map từ `his_service_type` (CASE
`Surgery→PTTM`, `Spa/Laser/Card→Beauty & Spa`, `Odontology→Nha khoa`, `wellness→Wellness`,
`weight_loss→Weight Loss`, còn lại → `Khác`) — giống hệt CTE `cline` bên dbt. Cột lấy trực tiếp từ
`view_stag_products` (KHÔNG đổi, đã xác nhận lại 2026-09-16, xem mục 7.5):

- `sp.product AS cline_service_name` — tên dịch vụ cụ thể.
- `sp.product_category AS cline_product_category` — **danh mục gốc, CHƯA gom nhóm** (input của
  CASE WHEN tạo ra `view_stag_products.product_group`).
- `sp.product_ctg_id AS cline_product_category_id`.

Join key không đổi: `sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl`.

`WHERE cl.id IN (SELECT crm_id FROM tmp_booking_id_co_tien_tc) AND cl.type = 'opportunity'` —
cấu trúc filter giữ nguyên, nhưng nội dung `tmp_booking_id_co_tien_tc` đã đổi (mục 7.1) nên **phạm
vi cline thực tế lọt qua bước này rộng hơn nhiều** so với tài liệu cũ.

> ⚠️ **Nghi vấn (chưa verify bằng data, vẫn còn nguyên ở bản 2026-09-16):** filter
> `WHERE cl.id IN (SELECT crm_id FROM tmp_booking_id_co_tien_tc)` chỉ so theo `cl.id`, không kèm
> `cl.brand_etl` — trong khi JOIN ngay phía trên (ở bản cũ) match cả `cl.id = spt.crm_id AND
> cl.brand_etl = spt.brand_etl`. Downstream có filter `brand_etl = 1` ở bước 3 nên rủi ro thực tế
> tuỳ vào việc `crm_id` có phải sequence global hay không.

### Bước 3 — `tmp_rnk_bl_cline`

Đánh số thứ tự cline: `cus_bl_cline_order` (theo `business_line, code_customer`),
`crm_cline_order` (theo `crm_id`, tức **trong cùng 1 booking**), `cus_cline_order` (theo
`code_customer`) — cả 3 đều `ORDER BY cline_created_date, cline_id` (kèm `cline_id` tie-break).
Lọc `brand_etl = 1` ở bước này. **Không đổi so với các bản trước, đã xác nhận lại 2026-09-16.**

`crm_cline_order = 1` (≡ `is_main_service_bk`) = "cline đầu tiên trong cùng booking" — đây là cột
tương đương đúng nghĩa với `stg_dv_khach_hang_quan_tam.cus_bk_line_order = 1` (dbt, xem
`README.md` func_report_marketing_ad_cost_kn mục 11) và cột mới `nhom_dv_KH_quan_tam_goc` —
**cùng partition (`crm_id`), cùng `ORDER BY`, cùng nguồn field `view_stag_products.product_category`
qua cùng join key** → logic khớp nhau ở phần này.

### Bước 3.5 — Nhóm dịch vụ chính (`tmp_nhom_dich_vu_chinh`)

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
   > ⚠️ **Nghi vấn (vẫn còn nguyên 2026-09-16):** không có `ROW_NUMBER()`/`WHERE rn = 1` để dedup
   > như tầng 1 và tầng 3 — nếu `cs_custom_fields` có nhiều dòng khớp `value_id + custom_field_id
   > = 9794`, 1 `crm_id` có thể ra nhiều dòng cùng tầng 2, kết quả có thể không ổn định giữa các
   > lần chạy.
3. **Tầng 3** (fallback, `tmp_uu_tien_3`): `product_category` (từ `view_stag_products`) của cline
   trong booking. **[Đổi 2026-09-16]** Tiêu chí chọn cline đổi từ `ORDER BY cln.create_date`
   (nhỏ nhất) sang **`ORDER BY cln.id`** (nhỏ nhất) — không còn dùng ngày tạo để chọn cline sớm
   nhất, mà dùng ID nhỏ nhất trực tiếp. Hai tiêu chí thường cho cùng kết quả (ID và ngày tạo
   thường đơn điệu cùng chiều) nhưng **không đảm bảo tuyệt đối giống nhau** — chưa verify bằng
   data sau khi đổi.

`tmp_nhom_dich_vu_chinh` gộp 3 tầng (`UNION ALL`), `ROW_NUMBER() OVER (PARTITION BY crm_id,
brand_etl ORDER BY do_uu_tien)`, lấy `rn = 1` (tầng số nhỏ hơn thắng). `his_service_type`/
`business_line` resolve qua `tmp_ctg_service_type_map` (mode `his_service_type` theo
`product_ctg_id`) nếu không map được trực tiếp thì fallback regex trên text
`nhom_dich_vu_chinh` (`TẠO HÌNH|PHẪU THU|CHUYỂN GIỚI → PTTM`, `... DA|CHÀM|NÁM...→ Beauty & Spa`,
`NHA KHOA → Nha khoa`, còn lại → `Khác`). **Không đổi so với bản trước.**

> ⚠️ **Nghi vấn cao (vẫn còn nguyên 2026-09-16):** `tmp_ctg_service_type_map` được `GROUP BY
> product_ctg_id, his_service_type` **không kèm `brand_etl`**, và join lại (`csm.product_ctg_id =
> r.product_category_id`) cũng **không kèm `brand_etl`**.

### Bước 3.6 — `tmp_customer_main_bl` (`main_bl_customer`)

Không đổi so với bản trước. `business_line` đã resolve qua 3 tầng ở bước 3.5 của **booking đầu
tiên của KH** (`crm_id` có `booking_report_date` sớm nhất, tie-break `cline_created_date`,
`cline_id`) — có thể `NULL` nếu booking đầu tiên không resolve được ở cả 3 tầng.

### Bước 4 — `tmp_paid_bl_cline`

Chỉ dòng có `cline_total_payment > 0`, đánh số `cus_bl_paid_order` theo `(business_line,
code_customer)`, `ORDER BY cline_payment_date, cline_id` — giống hệt CTE `paid_bl_cline` bên
dbt. **Không đổi.**

### Bước 5 — `tmp_labeling_1`

- `is_main_service` = `cus_cline_order = 1`; `is_main_service_bk` = `crm_cline_order = 1`.
- `is_line_over_6_months_in_bl`: so `cline_payment_date` hiện tại với dòng liền trước cùng BL
  đã có payment — cách nhau > 6 tháng → `true`.
- `main_bl_customer` / `source_main_bl`: từ `tmp_customer_main_bl` (bước 3.6).
- `main_bl_bk`: `first_value(business_line)` theo từng booking (`crm_id`) — chỉ tham khảo.
- `main_product_category(_id)`: `first_value` theo **`code_customer`** (toàn lịch sử KH).

**Không đổi so với bản trước.**

### Bước 7 — `tmp_main_bl_walkin`

**[Đổi 2026-09-16 — xem mục 7.2]** Vẫn lấy phiếu khám đầu tiên (theo `service_date_start`,
tie-break `w.id`) thuộc `business_line = main_bl_customer` của khách hàng, nhưng nay join thêm
`tmp_wsr_last_snapshot` để giới hạn theo snapshot ETL gần nhất (thay cho điều kiện cũ
`wsr.snapshot_date IS NOT NULL`) — xem mục 7.2.

### Bước 8 — `TRUNCATE` + `INSERT` (final), `is_cross_sale`

**[Đổi lớn 2026-09-16 — xem mục 7.4]** 2 nhánh của CASE `is_cross_sale` đã bị **comment out**
(vô hiệu hóa) trên bản sống — khác hẳn thiết kế mô tả trước đây ở mục 4. Xem mục 7.4 cho CASE đầy
đủ đang chạy thật.

## 4. `has_completed_walkin` — [ĐÃ VÔ HIỆU HÓA trên sandbox, xem mục 7.4]

**[Lịch sử]** Mục này từng ghi "đã deploy" (2026-08-26): gate `WHEN NOT has_completed_walkin THEN
false` được chèn vào `is_cross_sale`, dựa trên CTE `tmp_service_walkin_completed` (tập
`(crm_id, service_id, brand_etl)` có phiếu khám hợp lệ trong cùng booking).

**[Cập nhật 2026-09-16]** Đọc lại `pg_get_functiondef` cho thấy dòng gate này trong CASE cuối
(bước 8) đã bị **comment out** (`--WHEN NOT lb.has_completed_walkin THEN false`) — **không còn
hoạt động trên bản sống**, dù CTE `tmp_service_walkin_completed`/cột `has_completed_walkin` vẫn
được tính ra (chỉ là không dùng để chặn `is_cross_sale` nữa). Xem mục 7.4 để biết CASE đầy đủ hiện
tại và mục 7.2 cho các thay đổi khác trong chính CTE này (snapshot logic, đổi tên cột, thêm điều
kiện `state <> 'Cancelled'`).

> ⚠️ Model dbt `stg_crm_line_ecosystem.sql` **hiện vẫn giữ gate này active** (`when not
> lb.has_completed_walkin then false`) — dbt và sandbox **đang lệch nhau** ở điểm này kể từ khi
> nào không rõ (chỉ biết chắc là lệch tại thời điểm đọc 2026-09-16). Xem mục 7.6.

## 5. Cột ngày hoàn thành đầu tiên theo từng dòng dịch vụ — đổi tên 2 lần

Lịch sử tên cột: `line_walkin_finish_date` (thiết kế ban đầu, 2026-08-26) → `cline_walkin_finish_date`
(đổi 2026-08-27, "rõ nghĩa theo từng cline hơn") → **`cline_first_services_date`** (đổi lần nữa,
ghi nhận khi đọc lại 2026-09-16 — không rõ đổi chính xác ngày nào giữa 2026-08-27 và 2026-09-16).

- **Phạm vi tính**: trong cùng booking (`crm_id`) — không gộp theo toàn lịch sử khách hàng.
- Logic tính (`MIN(service_date_start + 7h)`) và join key không đổi, nhưng điều kiện lọc nguồn đã
  đổi thêm ở 2026-08-28 — xem mục 7.2.
- `has_completed_walkin` tương đương `cline_first_services_date IS NOT NULL` (vẫn tính cả 2 cột,
  không dùng để chặn `is_cross_sale` nữa — mục 4).

> ⚠️ Model dbt vẫn dùng tên cột cũ `cline_walkin_finish_date` — cột vật lý trên sandbox tên
> `cline_first_services_date`. Đây là lệch **tên cột**, ngoài lệch **logic** đã nêu ở mục 4/7.

## 6. Lịch sử đổi tên + sửa timezone/điều kiện `state` (2026-08-27) — ĐÃ xác nhận thực thi

Trước đây mục này ghi "Sandbox: CHƯA thực thi" cho 3 thay đổi (đổi tên cột, +7h cho
`service_date_start`, bỏ điều kiện `state = 'Completed'`). **[Xác nhận 2026-09-16]** Đọc lại
`pg_get_functiondef` cho thấy cả 3 thay đổi này **đã được áp dụng** trên bản sống (nằm trong các
thay đổi lớn hơn mô tả ở mục 7) — không cần chạy tay script cũ nữa, bản sống hiện tại **đã vượt
xa** 3 thay đổi đó (thêm snapshot logic, đổi thêm tên cột, sửa `is_cross_sale`...). Script cũ ở
mục này đã lỗi thời, xem script đầy đủ **hiện tại** ở mục 7.7.

## 7. Đọc lại `pg_get_functiondef` ngày 2026-09-16 — phát hiện nhiều thay đổi chưa ghi nhận

Bối cảnh: đối chiếu logic cột dbt mới `nhom_dv_KH_quan_tam_goc`
(`func_report_marketing_ad_cost_kn`, xem README.md mục 11 dự án đó) với procedure này. Phần liên
quan trực tiếp (bước 2/3 — nguồn `view_stag_products.product_category`, join key, tie-break "cline
đầu tiên trong booking") **khớp, không đổi**. Nhưng khi đọc toàn bộ định nghĩa để đối chiếu, phát
hiện procedure đã đổi **nhiều điểm khác** so với những gì mục 1–6 (bản trước) mô tả — comment
trong code (bước 1) còn ghi thẳng: *"GIỮ NGUYÊN bản sống hiện tại — xem cảnh báo lệch tài liệu ở
func_stag_crm_line_ecosystem.md mục 6, không sửa ở đây"* — tức là có người đã biết việc lệch tài
liệu trước đó nhưng chưa cập nhật lại file này. Toàn bộ mục 7 dưới đây ghi lại các đổi đó.

### 7.1. Bước 1 — điều kiện "có tiền thành công" đã đổi hẳn ý nghĩa

```sql
-- CŨ (tài liệu trước 2026-09-16, và vẫn là logic model dbt stg_booking_id_co_tien_tc.sql):
SELECT spt.crm_id, spt.brand_etl, SUM(spt.payment) AS total_payment
FROM stag_payment_transfer spt
    LEFT JOIN crm_lead cl ON cl.id = spt.crm_id AND cl.brand_etl = spt.brand_etl
WHERE cl.stage_id = 4
GROUP BY spt.crm_id, spt.brand_etl
HAVING SUM(spt.payment) > 0;

-- MỚI (bản sống đọc 2026-09-16):
SELECT cl.id AS crm_id, cl.brand_etl, SUM(spt.payment) AS total_payment
FROM crm_lead cl
    LEFT JOIN stag_payment_transfer spt ON spt.crm_id = cl.id AND spt.brand_etl = cl.brand_etl
WHERE cl.brand_etl > 0 AND cl.type_crm_id <> 1
GROUP BY cl.id, cl.brand_etl;
```

Khác biệt cốt lõi: **không còn** `WHERE cl.stage_id = 4` (đã có tiền thành công theo stage), và
**không còn** `HAVING SUM(payment) > 0` (aggregate vẫn tính `total_payment` nhưng không dùng nó để
lọc nữa — cột này giờ chỉ để tham khảo, không có tác dụng filter). Điều kiện lọc thật bây giờ là
`cl.brand_etl > 0 AND cl.type_crm_id <> 1` — hoàn toàn không liên quan đến payment. Đồng thời đổi
từ bảng gốc `stag_payment_transfer LEFT JOIN crm_lead` sang `crm_lead LEFT JOIN
stag_payment_transfer` (driving table đổi từ payment sang lead) — với điều kiện mới không lọc theo
payment, tập `crm_id` kết quả **gần như là "mọi booking có `type_crm_id <> 1`, mọi brand"**, rộng
hơn nhiều so với tập "đã có tiền thành công" trước đây. Tên bảng tạm (`tmp_booking_id_co_tien_tc`)
và tên các bước dùng lại nó (booking "có tiền thành công") **không còn phản ánh đúng nội dung**.

**Chưa rõ `type_crm_id` là gì** (không có trong tài liệu trước đây) — cần tra thêm nếu cần hiểu rõ
ý nghĩa nghiệp vụ của điều kiện `<> 1`.

### 7.2. Bước 1.4 (mới) + 1.5 (đổi) — lọc theo snapshot ETL gần nhất, thêm điều kiện `state`

**Bước 1.4 (`tmp_wsr_last_snapshot`, mới):**

```sql
SELECT brand_etl, MAX(date(snapshot_date)) AS last_snapshot_date
FROM sh_walkin_service_rel
WHERE snapshot_date IS NOT NULL
GROUP BY brand_etl;
```

Ngày batch ETL gần nhất đã "touch" `sh_walkin_service_rel`, theo từng `brand_etl` — mốc để nhận
diện dòng orphan (dữ liệu cũ chưa được batch mới nhất cập nhật/xoá), thay cho điều kiện cũ
`wsr.snapshot_date IS NOT NULL` (không đủ để loại orphan, theo comment trong code).

**Bước 1.5 (`tmp_service_walkin_completed`, đổi):**

```sql
SELECT w.booking_id AS crm_id, wsr.service_id, w.brand_etl,
    MIN(w.service_date_start + interval '7 hours') AS cline_first_services_date   -- đổi tên cột
FROM sh_medical_appointment_register_walkin w
    INNER JOIN sh_walkin_service_rel wsr ON wsr.walkin_id = w.id AND wsr.brand_etl = w.brand_etl
    INNER JOIN tmp_wsr_last_snapshot ls                                            -- MỚI
        ON ls.brand_etl = wsr.brand_etl AND date(wsr.snapshot_date) = ls.last_snapshot_date
WHERE w.service_date_start IS NOT NULL
    AND w.state <> 'Cancelled'                                                     -- MỚI
    AND w.booking_id IN (SELECT crm_id FROM tmp_booking_id_co_tien_tc)
GROUP BY w.booking_id, wsr.service_id, w.brand_etl;
```

3 thay đổi so với bản 2026-08-27: (1) thêm `INNER JOIN tmp_wsr_last_snapshot` — chỉ giữ dòng
walkin có `snapshot_date` đúng bằng ngày batch gần nhất của đúng `brand_etl` đó (loại dòng orphan
từ các batch cũ); (2) thêm `w.state <> 'Cancelled'` — trước đó (2026-08-27) đã bỏ hẳn điều kiện
`state`, giờ thêm lại nhưng chỉ loại `'Cancelled'` (khác hẳn yêu cầu `state = 'Completed'` ban
đầu); (3) đổi tên cột `cline_walkin_finish_date` → `cline_first_services_date`.

`tmp_cline` (bước 2) đổi tên cột tham chiếu theo (`swc.cline_first_services_date`); comment mới
trong code ghi: *"chỉ giữ ngày hoàn thành nếu CHÍNH dòng cline này đã dùng (number_used > 0 hoặc
stage = 'done') — tránh mượn nhầm ngày walkin của 1 dòng KHÁC cùng service_id trong cùng booking.
KHÔNG đổi has_completed_walkin ở trên"* — comment này mô tả 1 ý định/TODO, nhưng **code thực tế
chưa thấy áp dụng điều kiện `number_used`/`stage = 'done'` nào** ở bước join `swc` — có thể là ý
định cho lần sửa tiếp theo, chưa triển khai; **cần đọc lại procedure nếu cần xác nhận** thay vì
tin theo comment.

**Bước 7 (`tmp_main_bl_walkin_ranked`)** cũng đổi tương tự: thêm `INNER JOIN
tmp_wsr_last_snapshot` (thay `wsr.snapshot_date IS NOT NULL`), giữ nguyên phần còn lại (+7h,
không lọc `state`).

### 7.3. Bước 3.5, tầng 3 (`tmp_uu_tien_3`) — đổi tiêu chí chọn cline

```sql
-- CŨ: ROW_NUMBER() OVER (PARTITION BY cln.crm_id, cln.brand_etl ORDER BY cln.create_date)
-- MỚI: ROW_NUMBER() OVER (PARTITION BY cln.crm_id, cln.brand_etl ORDER BY cln.id)
```

Đổi từ "cline có ngày tạo sớm nhất" sang "cline có `id` nhỏ nhất". Chưa verify bằng data xem 2
tiêu chí có luôn cho cùng kết quả hay không.

### 7.4. Bước 8 — `is_cross_sale`: 2 điều kiện bị comment out

```sql
CASE
    WHEN lb.business_line = lb.main_bl_customer OR lb.main_bl_customer = 'Khác'
      OR lb.business_line = 'Khác' THEN false
    WHEN lb.source_main_bl = 'crm_lead_history' AND lb.partner_create_date < '2025-08-01' THEN FALSE
    --WHEN NOT lb.has_completed_walkin THEN false                                   -- ĐÃ TẮT
    WHEN bool_or(
            --coalesce(lb.cline_total_payment, 0) > 0 AND                          -- ĐÃ TẮT (phần này)
            (lb.cus_bl_paid_order = 1 OR lb.is_line_over_6_months_in_bl = true)
         ) OVER (PARTITION BY lb.crm_id, lb.business_line)
        THEN true
    ELSE false
END AS is_cross_sale
```

2 nhánh trước đây từng ghi là "đã deploy" (mục 4) nay đã bị **comment out** trên bản sống:

1. Gate `WHEN NOT has_completed_walkin THEN false` — không còn chặn `is_cross_sale` theo việc có
   phiếu khám hợp lệ hay không.
2. Điều kiện `coalesce(cline_total_payment, 0) > 0` bên trong `bool_or(...)` — điều kiện "kích
   hoạt" cross-sale giờ **không còn yêu cầu có payment thật**, chỉ cần `cus_bl_paid_order = 1 OR
   is_line_over_6_months_in_bl = true` (2 cột này bản thân đã được tính dựa trên tập
   `tmp_paid_bl_cline`, vốn **vẫn lọc `cline_total_payment > 0` ở bước 4** — nên điều kiện payment
   không biến mất hoàn toàn, chỉ là không kiểm tra lại lần 2 ở bước 8).

Chưa rõ đây là thay đổi tạm thời (debug/rollback dở dang) hay chủ đích lâu dài — comment `--` đơn
thuần là vô hiệu hóa, không có ghi chú ngày/lý do đi kèm như các thay đổi khác trong procedure.

### 7.5. Phần KHÔNG đổi (đã xác nhận lại 2026-09-16)

- Bước 2 (`tmp_cline`): nguồn `view_stag_products.product`/`product_category`/`product_ctg_id`,
  join key `product_id + brand_etl`, CASE `business_line` từ `his_service_type` — **giống hệt**
  bản trước. Đây là phần liên quan trực tiếp đến cột `nhom_dv_KH_quan_tam_goc` mới thêm bên
  `func_report_marketing_ad_cost_kn` — **logic khớp nhau**.
- Bước 3 (`tmp_rnk_bl_cline`): 3 `ROW_NUMBER()` (`cus_bl_cline_order`/`crm_cline_order`/
  `cus_cline_order`), đều `ORDER BY cline_created_date, cline_id` — **không đổi**.
  `crm_cline_order = 1` vẫn là "cline đầu tiên trong cùng booking", cùng partition/tie-break với
  `stg_dv_khach_hang_quan_tam.cus_bk_line_order = 1` bên dbt.
- Bước 3.5 tầng 1/tầng 2, `tmp_ctg_service_type_map`, bước 3.6, bước 4, bước 5 (trừ chỗ đã nêu ở
  trên) — **không đổi**, kể cả 2 nghi vấn logic cũ (thiếu dedup tầng 2, thiếu `brand_etl` ở
  `ctg_service_type_map`) vẫn còn nguyên.

### 7.6. Ảnh hưởng tới model dbt `stg_crm_line_ecosystem.sql`

Model dbt (`models/common/stg_crm_line_ecosystem.sql`) **hiện lệch với bản sống ở các điểm sau**
(dbt vẫn giữ logic cũ, procedure đã đổi):

1. Nguồn `tmp_booking_id_co_tien_tc`/`stg_booking_id_co_tien_tc.sql`: dbt vẫn `stage_id = 4 AND
   SUM(payment) > 0`; procedure đã đổi thành `brand_etl > 0 AND type_crm_id <> 1` (mục 7.1).
2. `is_cross_sale`: dbt vẫn có gate `when not has_completed_walkin then false` VÀ điều kiện
   `coalesce(cline_total_payment, 0) > 0` trong `bool_or(...)` — cả 2 đã bị tắt trên procedure
   (mục 7.4).
3. CTE `service_walkin_completed`: dbt chưa có snapshot-date filtering (`tmp_wsr_last_snapshot`,
   mục 7.2) và chưa có điều kiện `w.state <> 'Cancelled'`.
4. Tên cột: dbt dùng `cline_walkin_finish_date`; procedure đã đổi thành `cline_first_services_date`.
5. `tmp_uu_tien_3`/tầng 3: dbt vẫn `ORDER BY cln.create_date`; procedure đổi sang `ORDER BY cln.id`
   (mục 7.3).

**Đây là 5 điểm lệch hành vi số liệu thật (không chỉ đặt tên), chưa được đồng bộ.** Việc có nên
sửa dbt theo bản sống này hay không cần quyết định riêng (mục 7.1 đặc biệt đáng cân nhắc kỹ — thay
đổi phạm vi từ "chỉ booking có tiền thành công" sang gần như "mọi booking" là thay đổi lớn, có thể
ảnh hưởng nhiều xuống các báo cáo dùng `stg_crm_line_ecosystem`/`stag_crm_line_ecosystem`).

### 7.7. Script đầy đủ đang chạy thật trên sandbox (đọc `pg_get_functiondef`, 2026-09-16)

```sql
CREATE OR REPLACE PROCEDURE public.func_stag_crm_line_ecosystem()
 LANGUAGE plpgsql
AS $procedure$
BEGIN
    <<main_block>>
    BEGIN
    -- Bước 1: booking đã có tiền thành công (GIỮ NGUYÊN bản sống hiện tại — xem cảnh báo lệch tài
    -- liệu ở func_stag_crm_line_ecosystem.md mục 6, không sửa ở đây)
    DROP TABLE IF EXISTS tmp_booking_id_co_tien_tc;
    CREATE TEMP TABLE tmp_booking_id_co_tien_tc AS
        SELECT cl.id AS crm_id, cl.brand_etl, SUM(spt.payment) AS total_payment
        FROM "staging_sci"."public"."crm_lead" cl
            LEFT JOIN "staging_sci"."public"."stag_payment_transfer" spt
                ON spt.crm_id = cl.id AND spt.brand_etl = cl.brand_etl
        WHERE cl.brand_etl > 0 AND cl.type_crm_id <> 1
        GROUP BY cl.id, cl.brand_etl;
    -- Bước 1.4 [MỚI 2026-08-28]: ngày batch ETL gần nhất đã touch sh_walkin_service_rel, theo từng
    -- brand_etl -- mốc để nhận diện orphan thay cho "snapshot_date IS NOT NULL" (không đủ, xem
    -- func_stag_crm_line_ecosystem.md mục 8 / knowledge.md mục 9).
    DROP TABLE IF EXISTS tmp_wsr_last_snapshot;
    CREATE TEMP TABLE tmp_wsr_last_snapshot AS
        SELECT brand_etl, MAX(date(snapshot_date)) AS last_snapshot_date
        FROM "staging_sci"."public"."sh_walkin_service_rel"
        WHERE snapshot_date IS NOT NULL
        GROUP BY brand_etl;
    -- Bước 1.5 [ĐỔI 2026-08-27]: bỏ state='Completed' (chỉ giữ service_date_start IS NOT NULL),
    -- +7h cho service_date_start (bảng gốc lưu UTC), đổi tên cột -> cline_first_services_date.
    -- [SỬA 2026-08-28]: đổi "wsr.snapshot_date IS NOT NULL" -> join tmp_wsr_last_snapshot, chỉ giữ
    -- dòng có snapshot_date = ngày batch gần nhất của đúng brand_etl (loại đủ dòng orphan).
    DROP TABLE IF EXISTS tmp_service_walkin_completed;
    CREATE TEMP TABLE tmp_service_walkin_completed AS
    SELECT w.booking_id AS crm_id, wsr.service_id, w.brand_etl,
        MIN(w.service_date_start + interval '7 hours') AS cline_first_services_date
    FROM "staging_sci"."public"."sh_medical_appointment_register_walkin" w
        INNER JOIN "staging_sci"."public"."sh_walkin_service_rel" wsr
            ON wsr.walkin_id = w.id AND wsr.brand_etl = w.brand_etl
        INNER JOIN tmp_wsr_last_snapshot ls
            ON ls.brand_etl = wsr.brand_etl AND date(wsr.snapshot_date) = ls.last_snapshot_date
    WHERE w.service_date_start IS NOT NULL
		AND w.state <> 'Cancelled'
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
            -- FIX 2: chi giu ngay hoan thanh neu CHINH dong cline nay da dung (number_used > 0
            -- hoac stage = 'done') -- tranh muon nham ngay walkin cua 1 dong KHAC cung service_id
            -- trong cung booking. KHONG doi has_completed_walkin o tren.
            swc.cline_first_services_date
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
                ROW_NUMBER() OVER (PARTITION BY cln.crm_id, cln.brand_etl ORDER BY cln.id) AS rn
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
    -- cho service_date_start. [SỬA 2026-08-28]: đổi "wsr.snapshot_date IS NOT NULL" -> join
    -- tmp_wsr_last_snapshot (xem bước 1.4).
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
            INNER JOIN tmp_wsr_last_snapshot ls
                ON ls.brand_etl = wsr.brand_etl AND date(wsr.snapshot_date) = ls.last_snapshot_date
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
            --WHEN NOT lb.has_completed_walkin THEN false
            WHEN bool_or(
                    --coalesce(lb.cline_total_payment, 0) > 0 AND 
                    (lb.cus_bl_paid_order = 1 OR lb.is_line_over_6_months_in_bl = true)
                 ) OVER (PARTITION BY lb.crm_id, lb.business_line)
                THEN true
            ELSE false
        END AS is_cross_sale,
        lb.source_main_bl,
        lb.cline_first_services_date
    FROM tmp_labeling_1 lb
        LEFT JOIN tmp_main_bl_walkin mbw ON mbw.code_customer = lb.code_customer;

    -- Dọn bảng tạm khi chạy thành công
    DROP TABLE IF EXISTS tmp_booking_id_co_tien_tc;
    DROP TABLE IF EXISTS tmp_wsr_last_snapshot;
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
        DROP TABLE IF EXISTS tmp_wsr_last_snapshot;
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

Đây là bản đọc trực tiếp bằng `pg_get_functiondef('public.func_stag_crm_line_ecosystem'::regproc)`
ngày 2026-09-16 (chỉ SELECT, không CALL/không sửa gì trên sandbox) — nguồn xác thực duy nhất, thay
thế hoàn toàn script "chưa thực thi" từng ghi ở mục 6 (bản đó đã lỗi thời).
