# Knowledge dùng chung (áp dụng cả import_dichvu_sci và import_banggia_sci)

File này là bản sao trong repo của memory cross-session đã lưu khi chuyển đổi
2 pipeline `import_dichvu_sci`/`import_banggia_sci` — để ai đọc code cũng
thấy được, không chỉ nằm trong memory riêng của trợ lý. Nội dung giống hệt
`models/import_banggia_sci/KNOWLEDGE.md` (giữ đồng bộ 2 bản khi cập nhật).
Khác với `LOGIC.md` (logic/gap dữ liệu **riêng của pipeline này**), file này
ghi **kiến thức/convention dùng chung** cho cả nhóm pipeline `import_*_sci`
và cho việc thao tác với các database ERP liên quan.

## 1. Convention chuyển đổi `update_import_XXX()` -> dbt

Khi cần chuyển 1 function plpgsql kiểu `update_import_XXX()` (đọc bảng nhập
liệu tay qua Excel, đối chiếu ERP, gắn cờ lỗi trước khi ghi vào bảng
`output_import_XXX`) sang dbt trong `data_serving`, dùng đúng pattern đã áp
dụng cho `import_dichvu_sci` và `import_banggia_sci`:

- Cấu trúc 3 tầng `stg/int/mart` trong `models/import_<ten>_sci/`. `stg` đọc
  `source()`/seed không biến đổi logic. `int` port **1:1** từng
  CTE/temp-table gốc thành 1 model riêng — **không đổi tên cho "dễ hiểu
  hơn"**, không gộp/tối ưu lại logic (kể cả tên CTE gốc kiểu `a`, `d`, `k`,
  `p`, `g`) để giảm rủi ro sai lệch logic khi không đối chiếu được với bản
  gốc. `mart` là model cuối (tương đương `INSERT INTO output_import_XXX`).
- `int: +materialized: table` trong `dbt_project.yml` (không `ephemeral` như
  mặc định các nhóm report khác) — vì nhiều CTE bị nhiều bước sau `ref()` lại
  nhiều lần, đúng lý do bản gốc dùng `CREATE TEMP TABLE`.
- Mart dùng `{{ config(alias='output_import_XXX_dbt') }}` — build ra bảng
  riêng, không ghi đè bảng `output_import_XXX` thật cho tới khi đối chiếu
  xong (cutover là bước riêng, dỡ alias sau).
- Bảng nhập liệu tay qua Excel chuyển thành **dbt seed**, tên seed khác bảng
  ERP gốc (hậu tố `_seed`) để tránh `dbt seed` DROP/CREATE đè lên bảng ERP
  đang sống. Quy trình: export Excel -> **"CSV UTF-8 (Comma delimited)"**
  (không phải CSV thường, hỏng cột tiếng Việt có dấu) -> `dbt seed --select
  <seed> --full-refresh` -> `dbt run --select import_<ten>_sci`.
- Mỗi nhóm có `LOGIC.md` riêng: bài toán gốc, mapping CTE -> model, lý do
  `int` là `table`, tình trạng dữ liệu ERP theo brand, kế hoạch cutover — cập
  nhật liên tục khi chạy thử thật phát hiện gap. `LOGIC.md` lưu chi tiết
  riêng từng pipeline; file `KNOWLEDGE.md` này lưu phần dùng chung.

**Đã xác nhận đúng qua thực chiến (2026-08-01, lúc chuyển đổi
`import_banggia_sci`)**: giữ logic y hệt bản gốc giúp cô lập vấn đề nằm ở dữ
liệu ERP, không phải ở bản dịch sang dbt — hầu hết lỗi khi chạy thử là do
lệch schema thật/gap đồng bộ, không phải lỗi port.

## 2. Cơ chế `__export__` của `ir_model_data` (Odoo) — ảnh hưởng mọi pipeline dùng external ID

Khi export 1 bản ghi Odoo (bất kỳ model nào) từ UI kèm cột External ID mà bản
ghi đó **chưa có** `ir.model.data` (record tạo tay qua UI, không qua
import/XML data), Odoo **tự ghi vĩnh viễn** 1 dòng mới vào `ir_model_data`
với `module = '__export__'`, `name = '<table>_<res_id>_<hash>'`. Đây là giá
trị **được persist thật**, không phải tính runtime rồi bỏ — export lại lần
sau sẽ đọc đúng dòng đó (đã kiểm chứng trực tiếp trên `kn_erp`).

Query/model dùng `concat(module,'.',name)` để lấy external id (như dùng ở
`int/int_idvs_*` trong pipeline này) hoạt động đúng với cả external id
"thật" (module thật) lẫn dạng `__export__.xxx` — không cần xử lý riêng. Nếu
1 bản ghi báo "thiếu external id"/cần kéo `ir_model_data`: **cách khắc phục
là export chính bản ghi đó từ UI Odoo 1 lần** (đúng model cần, đúng view —
vd muốn external id cho `sh.medical.health.center.service` phải export đúng
view của model đó), **không phải** tính/backfill từ nguồn khác trước.

**`new_product` là bản sao đồng bộ ĐỊNH KỲ (không live) từ `kn_erp`**: export
xong trên `kn_erp`, dòng `__export__` mới xuất hiện ngay trên `kn_erp` nhưng
**chưa có** trên `new_product` cho tới khi backfill tay hoặc chờ job đồng bộ
(chưa xác định được chu kỳ job này). Lưu ý độ trễ này khi debug "tại sao vừa
export mà vẫn chưa thấy" trên `new_product`.

**Convention backfill thủ công `ir_model_data`** (mục "Database nguồn ERP"
trong `LOGIC.md` của pipeline này đã mô tả cách backfill theo khoá `(id,
model)` cho các bảng rel/`ir_model_data` — cùng convention, bổ sung chi tiết
cột ETL): merge theo khoá `(res_id, model)`, chỉ insert phần thiếu, gắn 4
cột ETL metadata mà `new_product` có nhưng nguồn không có: `snapshot_date =
current_date`, `ingestion_timestamp = now()`, `source_server =
'manual_backfill_<tên nguồn>'` (vd `manual_backfill_kn_erp`,
`manual_backfill_dev_staging_sci`), `brand_etl = N`. Các cột Odoo gốc khác
(`create_date`, `write_date`, `date_init`, `date_update`, `create_uid`,
`write_uid`) để `NULL`, `noupdate = false`.

**Lưu ý kỹ thuật khi insert số lượng lớn qua `psycopg2.extras.execute_values`**:
`cursor.rowcount` sau khi gọi chỉ phản ánh batch cuối (mặc định page_size=100,
chia nhiều statement) — **không** phải tổng số dòng đã insert; luôn verify
lại bằng `count(*)`/`select` trực tiếp trên DB, đừng tin `rowcount` cho thao
tác nhiều trang.

## 3. Database ERP liên quan

- **`new_product`** (target `dev` hiện active trong `data_serving/profiles.yml`,
  kết nối/credential xem file đó) — đa brand (cột `brand_etl`). Bản sao đồng
  bộ định kỳ (không live) từ nguồn ERP gốc (xem mục 2). Chỉ đồng bộ đầy đủ
  cho `brand_etl = 8`; brand 1/3/4/7 thiếu nhiều nhất ở `ir_model_data`.
- **`dev_staging_sci`** (target `dev` cũ, đang comment trong `profiles.yml`,
  cùng file) — đa brand, đầy đủ hơn `new_product` cho brand 0/1/3/4/7 nhưng
  vẫn không phải nguồn gốc.
- **`kn_erp`** — ERP gốc đơn brand KangNam (brand_etl=1, không có cột
  `brand_etl`). Có ít nhất 2 endpoint kết nối khác nhau nhưng trỏ **cùng 1
  database vật lý** (row count/`ir_model_data` khớp tuyệt đối khi đối chiếu
  2026-08-01); 1 trong 2 từng gặp `SerializationFailure: canceling statement
  due to conflict with recovery` khi query lâu — dấu hiệu hot-standby/read
  replica, ưu tiên endpoint còn lại nếu cần query dài. Credential không lưu
  ở đây (rủi ro bảo mật nếu để trong file repo) — hỏi lại người phụ trách
  hạ tầng/ERP khi cần kết nối.
- Client dùng: `psycopg2-binary` (có sẵn trong môi trường), không có `psql`
  CLI. In tiếng Việt qua `python -c`/heredoc trên Windows cần
  `sys.stdout.reconfigure(encoding='utf-8')` trước, tránh `UnicodeEncodeError`
  với `cp1252`.
