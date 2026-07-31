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
4. Chạy:
   ```
   dbt seed --select import_danhmuc_dichvu_sci_seed
   dbt run --select import_dichvu_sci
   ```
5. Xem kết quả ở bảng `output_import_dichvu_dbt` (xem mục "Cutover").

Toàn bộ 44 cột được khai báo `varchar` trong `column_types`, trừ `stt` là
`integer` (cột duy nhất được dùng trần trong mọi `ORDER BY`/`JOIN` xuyên suốt
function gốc mà không có `::type` cast nào — các cột khác đều được cast tường
minh (`::numeric`, `::text`...) ở đâu đó trong function, cho thấy bảng thật
vốn cũng lưu dạng text/varchar lỏng lẻo; ép `varchar` giữ đúng hành vi này,
tránh dbt tự suy kiểu số/ngày từ nội dung CSV rồi lệch với logic parse sẵn có
trong `int_idvs_input_data`, vd. so sánh chuỗi `is_surgeries = '1.0'`).

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
