# Logic: import_dichvu_sci

Chuyển function `public.update_import_dichvu()` (plpgsql, chạy `EXECUTE` trên
chuỗi SQL động, xây 8 bảng tạm tuần tự bằng `CREATE TEMP TABLE ... AS`) sang
dbt. Output: `mart_output_import_dichvu`, alias vật lý `output_import_dichvu_dbt`
(xem mục "Cutover" — **chưa** ghi đè bảng `output_import_dichvu` thật).

## Bài toán gốc

Function đọc dữ liệu người dùng nhập tay vào bảng `import_danhmuc_dichvu_sci`
(qua template Excel), đối chiếu với danh mục dịch vụ hiện có trong ERP
(`product_product`, `sh_medical_health_center_service`, ...) để suy ra các
`id`/quan hệ còn thiếu (institution, service_department, service_room,
exam_room, category, uom, lab/imaging type...), rồi gắn cờ lỗi
(`data_status`, `is_record_false`) cho từng dòng trước khi ghi vào
`output_import_dichvu` để người dùng xem lại trên UI.

## Nhập liệu qua seed (thay cho bảng ERP `import_danhmuc_dichvu_sci`)

Bảng gốc `import_danhmuc_dichvu_sci` trước đây được ghi trực tiếp vào Postgres
bởi quy trình ngoài dbt (UI/import Excel). Pipeline dbt này đổi nguồn nhập
liệu sang **dbt seed**:

- File: `seeds/import_danhmuc_dichvu_sci_seed.csv` (tên seed =
  `import_danhmuc_dichvu_sci_seed`, khai báo type ở `seeds/seeds.yml`).
- `stg_idvs_import_danhmuc_dichvu_sci` đọc từ `{{ ref('import_danhmuc_dichvu_sci_seed') }}`
  thay vì `source('idvs_erp', 'import_danhmuc_dichvu_sci')` — bảng ERP cũ đã
  bỏ khỏi `stg/sources.yml`.
- **Cố tình đặt tên seed khác** bảng ERP gốc (`..._seed` suffix), không tái sử
  dụng thẳng tên `import_danhmuc_dichvu_sci`: `dbt seed` DROP + CREATE lại
  bảng đích mỗi lần chạy theo type suy từ CSV/`column_types`, nếu trỏ thẳng
  vào bảng ERP đang sống (có thể có index/constraint/quyền riêng chưa rõ) sẽ
  là hành động phá huỷ không hoàn tác được ngay lần chạy đầu. Sau khi đối
  chiếu ổn, có thể đổi tên bảng thật/đổi alias seed để seed ghi thẳng vào
  đúng chỗ UI cũ từng ghi (hoặc bỏ hẳn bảng ERP cũ) — bước "chốt" riêng, chưa
  làm ở đây.

### Quy trình nhập liệu (cho người dùng nghiệp vụ)

1. Mở `seeds/import_danhmuc_dichvu_sci_seed.csv`, xoá hết dữ liệu cũ (giữ
   dòng header), dán/nhập dữ liệu batch mới (từ Excel) vào.
2. Khi export/save từ Excel: chọn đúng **"CSV UTF-8 (Comma delimited)
   (*.csv)"** trong hộp thoại Save As — **không** chọn "CSV (Comma
   delimited)" thường, vì định dạng đó lưu theo ANSI/Windows-1252 và sẽ làm
   hỏng các cột tiếng Việt có dấu (`default_code cũ`, `hướng dẫn sau dịch
   vụ`, `tính hoa hồng ctv`...).
3. Header phải khớp chính xác tên cột đã khai báo trong
   `seeds/seeds.yml` (kể cả khoảng trắng, dấu `/`, chữ có dấu).
4. Chạy (cần `--full-refresh` cho seed nếu cấu trúc cột CSV vừa đổi, xem
   checklist bên dưới):
   ```
   dbt seed --select import_danhmuc_dichvu_sci_seed --full-refresh
   dbt run --select import_dichvu_sci
   ```
5. Xem kết quả ở bảng `output_import_dichvu_dbt` (xem mục "Cutover").

Toàn bộ cột được khai báo `varchar` trong `column_types`
(`seeds/seeds.yml`), trừ 2 ngoại lệ suy ra được từ cách function gốc dùng
cột đó **không hề cast** (mọi cột khác đều bị cast tường minh `::numeric`,
`::text`... ở đâu đó trong function — dấu hiệu bảng thật vốn lưu
text/varchar lỏng lẻo):

- `STT` (chú ý viết hoa nguyên văn — khớp header thật của template Excel,
  không phải `stt` thường): `integer`, vì dùng trần trong mọi
  `ORDER BY`/`JOIN` xuyên suốt function.
- `brand`: `integer`, vì so sánh trực tiếp với `brand_etl` (integer) của các
  bảng ERP (`idds.brand = a.brand_etl`) không qua cast nào.

### Checklist dữ liệu CSV hay gặp lỗi (đúc kết từ lần chạy thử đầu tiên)

Đây là các lỗi thực tế đã gặp khi 1 CSV thật (khác template rỗng ban đầu)
được nạp — liệt kê để lần sau không phải dò lại từ đầu:

- **Header phải khớp *chính xác*** tên cột trong `seeds/seeds.yml`, kể cả
  hoa/thường. Cột `STT` viết hoa nếu CSV ghi `stt` (hoặc ngược lại) sẽ tạo
  ra bảng seed với tên cột khác — Postgres phân biệt hoa/thường cho định
  danh có quote, lỗi `column "stt" does not exist` khi build model.
- **Cột `default_code` phải tồn tại** (được phép để trống), kể cả khi CSV
  chỉ điền `default_code cũ`/`default_code mới` — vì `coalesce(...)` trong
  `stg_idvs_import_danhmuc_dichvu_sci` tham chiếu thẳng tên cột này, thiếu
  cột (không phải thiếu giá trị) sẽ lỗi `column "default_code" does not
  exist`.
- **`ceiling_discount_ids/ceiling_discount` phải là số thập phân thuần**
  (vd. `0.57` cho 57%), **không** được ghi kèm dấu `%` (`"57%"`) — code gốc
  làm `::numeric * 100`, không tự strip `%`. Nếu Excel/CSV quen ghi kèm `%`,
  phải tự convert trước khi seed (57% -> 0.57, 0% -> 0).
- **`his_service_type` phải là code nội bộ hệ thống**, không phải nhãn hiển
  thị tiếng Việt tự do. Xem mục enum bên dưới.
- Giá trị nào chứa dấu `,` (chủ yếu `lab_type_ids/id`, `imaging_type_ids/id`
  — vốn là danh sách nhiều mã cách nhau bởi `,`) phải được bọc `"..."` theo
  chuẩn CSV (RFC 4180) — Excel tự làm việc này khi export "CSV UTF-8", chỉ
  cần tự tay quote nếu sửa file `.csv` trực tiếp bằng text editor.

### `his_service_type` — enum thật lấy ở đâu

Function gốc có 1 đoạn `CASE trim(idds.his_service_type) WHEN 'Nha' THEN
'Odontology' WHEN 'Chi phí khác' THEN 'ChiPhi' WHEN 'Spa' THEN 'Spa' WHEN
'Phẫu thuật' THEN 'Surgery' WHEN 'Laser' THEN 'Laser' WHEN 'Chăm sóc sức
khỏe' THEN 'wellness' ELSE trim(idds.his_service_type) END` trong
`int_idvs_input_data` — đây **chỉ là bảng dịch 6 nhãn tiếng Việt cụ thể**
sang code nội bộ, KHÔNG phải danh sách đầy đủ giá trị hợp lệ. Giá trị nào
không khớp 6 nhãn này thì giữ nguyên (`ELSE`) rồi đem so khớp thẳng với code
nội bộ ở bước sau (`sh_medical_health_center_ward.type`,
`sh_medical_health_center_ot.room_type`,
`sh_medical_health_center_service.his_service_type`) để suy
institution/department/room mặc định cho dịch vụ mới.

Enum thật = tập hợp giá trị distinct của 3 cột trên, **theo từng brand** (có
brand-specific code, ví dụ `weight_loss` chỉ tồn tại ở brand_etl = 1/KangNam,
không có ở brand 3/4/7/8) — cách tra nhanh:
```sql
select distinct his_service_type from sh_medical_health_center_service where brand_etl = <brand>;
select distinct type from sh_medical_health_center_ward where brand_etl = <brand>;
select distinct room_type from sh_medical_health_center_ot where brand_etl = <brand>;
```
Nếu người dùng nhập đúng 1 trong 6 nhãn tiếng Việt ở trên thì được tự dịch;
mọi giá trị khác (kể cả các brand-specific code như `weight_loss`) phải nhập
**đúng nguyên văn code nội bộ**, không phải nhãn hiển thị tự do.

**Khoảng trống vận hành chưa xử lý**: ai/cái gì sẽ chạy 2 lệnh `dbt seed` +
`dbt run` ở trên mỗi khi có batch import mới (CLI thủ công, script, hay job
lên lịch/Airflow theo dõi thư mục `seeds/`) — cần quyết định riêng tuỳ hạ
tầng hiện có, ngoài phạm vi chuyển đổi function này.

## Ánh xạ bảng tạm -> model

| Bước gốc | Tên bảng tạm | Model dbt |
|---|---|---|
| 0 | (UPDATE tại chỗ trên `import_danhmuc_dichvu_sci`) | `stg/stg_idvs_import_danhmuc_dichvu_sci` (đọc từ seed, xem mục trên) |
| 1 | `system_data` | `int/int_idvs_system_data` |
| 2 | `input_data` | `int/int_idvs_input_data` |
| 3 | `data_processing` | `int/int_idvs_data_processing` |
| 4 | `update_id_old_code` | `int/int_idvs_update_id_old_code` |
| 5 | `update_id_new_code` | `int/int_idvs_update_id_new_code` |
| 6 | `data_after_update` | `int/int_idvs_data_after_update` |
| 7 | `note_data` | `int/int_idvs_note_data` |
| 8 | `output_data` (+ `INSERT INTO output_import_dichvu`) | `mart/output_import_dichvu` |

Mỗi model chỉ `ref()` đúng (các) bảng tạm nó phụ thuộc trực tiếp (đọc từ
`RAISE NOTICE 'Xong bước N!'` và grep tên bảng tạm trong từng khối SQL gốc để
xác định), giữ nguyên toàn bộ join/subquery/CTE lồng nhau — kể cả các chỗ
dùng `WITH` lồng trong `WITH` (hợp lệ trong Postgres, y hệt bản gốc).

## Vì sao int là `table`, không `ephemeral` (khác quy ước các nhóm khác)

Bản gốc cố tình dùng `CREATE TEMP TABLE` thay vì subquery/CTE cho từng bước —
vì `system_data`, `data_processing`, `update_id_old_code` được nhiều bước sau
`ref` lại nhiều lần (vd. `system_data` được dùng ở bước 3, 4 và 7). Nếu để
`ephemeral`, dbt sẽ inline lại toàn bộ CTE cha mỗi lần bị ref, tức tính lại
từ đầu — đúng chi phí mà bản gốc dùng temp table để tránh. Do đó
`dbt_project.yml` đặt `int: +materialized: table` riêng cho nhóm này.

## Xử lý bước UPDATE default_code (bước 0)

Bản gốc `UPDATE import_danhmuc_dichvu_sci SET ...` để tự suy `default_code`,
`"default_code cũ"`, `"default_code mới"` từ nhau khi người dùng chỉ điền 1
trong 3 cột — chạy 1 lần, mutate bảng, các bước sau đọc lại bảng đã sửa.
dbt không mutate source nên logic này chuyển thành `SELECT` trong
`stg_idvs_import_danhmuc_dichvu_sci`. **Mọi** chỗ trong function gốc còn lại
tham chiếu thẳng `import_danhmuc_dichvu_sci` (không qua `input_data`) — ví dụ
2 subquery unnest `lab_type_ids/id` / `imaging_type_ids/id` ở bước 3, và
subquery phát hiện `default_code` trùng ở bước 7 — đều đã ref
`stg_idvs_import_danhmuc_dichvu_sci` (không phải source trực tiếp), để đảm
bảo thấy đúng giá trị `default_code` đã được suy ra, khớp hành vi bản gốc
(vì UPDATE chạy trước, mọi SELECT sau đó trong cùng function đều thấy bản đã
sửa).

Ba cột SET trong UPDATE gốc đọc giá trị **trước khi sửa** của cả 3 cột (ngữ
nghĩa UPDATE ... SET trong Postgres: mọi vế phải cùng đọc từ dòng cũ, không
phụ thuộc thứ tự các SET khác) — nên chuyển thành 1 SELECT tính cả 3 cột từ
giá trị gốc là tương đương chính xác, không có vấn đề phụ thuộc thứ tự.

## Quote-escaping khi trích xuất

Function gốc bọc từng câu SQL động trong 1 string literal plpgsql
(`query := '...';`), nên mọi `'` literal bên trong phải viết thành `''`. Toàn
bộ 11 khối `query := '...'` được trích xuất và un-escape (`''` → `'`) bằng
script, không gõ tay, để tránh sai sót transcription trên ~700 dòng SQL có
nhiều định danh tiếng Việt/dấu ngoặc kép.

## Database nguồn ERP — bản đồ & khoảng trống dữ liệu đã phát hiện

Lần chạy thử đầu tiên (71 dòng test brand_etl = 1 / KangNam) fail liên tục
không phải do lỗi model, mà do database đích cấu hình trong `profiles.yml`
(`new_product` @ `10.10.10.214:5432`) **chỉ đồng bộ đầy đủ cho brand_etl = 8**
— các brand khác (1/3/4/7) chỉ có 1 phần nhỏ dữ liệu ở nhiều bảng ETL dùng để
suy institution/department/room/category (`ir_model_data`,
`service_departments_rel`, `service_rooms_rel`, `exam_rooms_rel`,
`sh_medical_health_center_sh_medical_health_center_service_rel`,
`sh_medical_health_center_uom_guarantee`, `sh_medical_labtest_types`,
`sh_medical_imaging_test_type`...). Các bảng "hiện vật" chính (`product_product`,
`sh_medical_health_center_service`...) thì có đủ data cho mọi brand — dễ gây
ngộ nhận database đã đầy đủ.

Các database liên quan đã xác định được trong quá trình debug:

| Database | Vai trò | Ghi chú |
|---|---|---|
| `new_product` @ `10.10.10.214:5432` | Target dbt đang dùng (`profiles.yml`, target `dev`) | Multi-brand (cột `brand_etl`), chỉ đầy đủ cho brand 8; brand 1/3/4/7 thiếu nhiều ở các bảng rel/`ir_model_data` |
| `dev_staging_sci` @ `10.10.10.224:5432` | Target `dev` cũ (bị comment trong `profiles.yml`) | Multi-brand, đầy đủ hơn `new_product` cho brand 0/1/3/4/7 nhưng **vẫn không phải nguồn gốc** — vd. `ir_model_data` brand 1 chỉ có 91.695 dòng ở đây so với 6.233.762 dòng thật ở `kn_erp` (phần lớn chênh lệch là các Odoo model khác không liên quan tới pipeline này) |
| `kn_erp` @ `10.10.10.221:54306` (user `report_user`) | ERP gốc, đơn brand, của **KangNam (brand_etl = 1)** | Không có cột `brand_etl` (đơn brand nên không cần) — dùng làm nguồn đối chiếu/backfill chính xác nhất cho brand 1 |
| `sci_erp` @ `10.10.10.154:54321` (user `reporter`) | ERP gốc đơn brand khác | Đã thử nhưng **không phải nguồn của brand 1** (không rõ brand nào) — không dùng tiếp, ghi lại để không thử nhầm lần sau |

**Cách kiểm tra database đích có đủ dữ liệu cho 1 brand hay không** trước khi
chạy pipeline: so sánh row count giữa `new_product` (filter `brand_etl = N`)
và ERP gốc đơn-brand tương ứng (không filter, vì đơn brand) cho từng bảng
trong `stg/sources.yml`. Nếu lệch lớn — không phải lỗi model, cần backfill.

**Cách backfill đã dùng (merge theo khoá, không đụng dữ liệu có sẵn)**: với
mỗi bảng thiếu, lấy tập khoá tự nhiên đã có ở `new_product` (filter đúng
brand_etl), lấy toàn bộ dòng từ ERP gốc, chỉ insert dòng có khoá **chưa tồn
tại**, gắn thêm 4 cột ETL metadata mà `new_product` có nhưng ERP gốc không
(`snapshot_date = current_date`, `ingestion_timestamp = now()`,
`source_server = 'manual_backfill_<tên db nguồn>'`, `brand_etl = N`). Khoá
dùng cho từng bảng:

| Bảng | Khoá merge |
|---|---|
| `ir_model_data` | `(id, model)` — **chỉ lấy các `model` pipeline thực sự dùng** (grep `\.model\s*=\s*'...'` trong `models/import_dichvu_sci`), không copy nguyên bảng (hàng triệu dòng, đa số không liên quan) |
| `import_service_brand_rh` | toàn bộ (bảng nhỏ, không phải bảng ERP nên không có ở `kn_erp`/`sci_erp`, chỉ có ở `dev_staging_sci`) |
| `sh_medical_health_center_uom_guarantee` | `id` |
| `sh_medical_health_center_sh_medical_health_center_service_rel` | `(sh_medical_health_center_service_id, sh_medical_health_center_id)` |
| `service_departments_rel` | `(sh_medical_health_center_service_id, sh_medical_health_center_ward_id)` |
| `service_rooms_rel`, `exam_rooms_rel` | `(sh_medical_health_center_service_id, sh_medical_health_center_ot_id)` |
| `sh_medical_labtest_types`, `sh_medical_imaging_test_type` | `id` |

Không có bảng nào trong danh sách trên có PK/unique constraint ở
`new_product` — merge theo khoá tự làm ở tầng ứng dụng (không dựa vào
`ON CONFLICT`).

**Kết quả đối chiếu sau backfill** (71 dòng test, brand 1, dịch vụ "Giảm
béo"): 68/71 dòng `is_record_false = false`; 3 dòng còn lại thiếu
`service_category/id`/`service_department/id`/`service_room/id`/`exam_room/id`
riêng lẻ — khả năng cao là gap dữ liệu thật ở đúng 3 dịch vụ đó trong ERP
(không phải lỗi hệ thống, vì tỉ lệ lỗi đã giảm từ 71/71 xuống 3/71 sau khi
backfill xong), chưa điều tra tiếp.

## Cutover — kế hoạch chuyển từ function sang dbt

Model hiện build ra bảng riêng `output_import_dichvu_dbt` (không đụng
`output_import_dichvu` thật) qua `{{ config(alias=...) }}` trong
`mart/output_import_dichvu.sql`. Để "chốt":

1. Đối chiếu dữ liệu `output_import_dichvu_dbt` vs `output_import_dichvu`
   thật ngay sau khi chạy `update_import_dichvu()` với cùng dữ liệu
   `import_danhmuc_dichvu_sci` (số dòng, `data_status`, `is_record_false`,
   từng cột) — nên chạy sát thời điểm cutover vì ERP là dữ liệu sống.
2. Bỏ dòng `config(alias=...)` để dbt build thẳng ra bảng
   `output_import_dichvu` (cần quyền DROP/CREATE trên bảng đó).
3. Gỡ/replace lệnh gọi `update_import_dichvu()` ở nơi đang trigger nó (UI
   import Excel / job) bằng lệnh `dbt run --select import_dichvu_sci`.
4. Có thể xoá function `update_import_dichvu()` sau khi xác nhận không còn
   nơi nào gọi.
