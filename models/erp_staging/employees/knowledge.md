# knowledge.md — erp_staging/employees: bài học mới so với products

Bài toán/quy trình đối chiếu chung (dùng `dbt show --inline`, `EXCEPT` 2
chiều, cách kiểm tra khoá tự nhiên không lịch sử hoá...) đã ghi ở
`erp_staging/products/knowledge.md` — không lặp lại ở đây. File này chỉ ghi
**những gì mới** phát hiện khi làm `stag_employees`.

## 1. Trước khi dịch 1 hàm pandas, luôn hỏi: "phần dữ liệu này còn được pipeline ghi lại không?"

`write_stag_employees()`:
```python
query_df(conn, f'''DELETE FROM {table} WHERE id > 0''', ret='exe')
insert_data_to_db(dfc, table)
```
So với `write_stag_products()` (`DELETE FROM {table};` — xoá **sạch** bảng).
Chỉ cần đọc lướt cũng dễ bỏ sót chi tiết `WHERE id > 0` này — hậu quả nếu bỏ
sót: dịch đúng 100% phần `get_data_employee()` nhưng vẫn thiếu ~7% dữ liệu
thật (316/4515 dòng) mà không có dấu hiệu lỗi rõ ràng nào trong logic SQL để
lần ra (vì đúng là logic SQL **không** tạo ra các dòng đó — chúng đến từ 1 lần
import thủ công đã xảy ra **trước khi có DAG này**).

**Quy tắc chung khi dịch 1 hàm `write_stag_*`**: đọc kỹ câu `DELETE` đi kèm
`INSERT`, không chỉ hàm build DataFrame. `DELETE FROM x` (không điều kiện) =
build lại toàn bộ, an toàn khi chỉ dịch phần SELECT. `DELETE FROM x WHERE
<điều kiện>` = có phần dữ liệu **cố ý được bảo tồn** qua điều kiện phủ định —
phải tìm ra phần đó đến từ đâu (seed có sẵn? bảng khác? import thủ công đã mất
dấu vết?) trước khi kết luận đã dịch đủ.

## 2. Repo đã có sẵn manh mối — kiểm tra `seeds/` trước khi hard-code lại dictionary trong Python

2 việc trong code Python gốc hoá ra đã có sẵn dưới dạng seed, không cần dịch
lại thủ công:

- `dict_job`/`dict_emp` (hard-code job_lv2 cho bác sĩ KNHN) → **đã là**
  `seeds/import_stag_employee_doctor.csv`, khớp dữ liệu 100%.
- Comment `data_fix` trong docstring (dead code) → **đã là**
  `seeds/import_employee.csv` — nhưng seed này hoá ra **không dùng được** (chỉ
  2 dòng, đến từ code chết) — điểm mấu chốt là seed **có tồn tại không đồng
  nghĩa với đang được dùng**, phải đối chiếu với bảng thật để biết seed nào
  đúng là nguồn hiện hành (`import_stag_employee_null`, khớp 100%) và seed nào
  là di sản không còn liên quan.

**Cách kiểm tra 1 seed có phải nguồn hiện hành hay không**: so trực tiếp với
bảng thật bằng khoá chính (ở đây là `id`), 2 chiều:
```sql
select 'seed_not_in_real', count(*) from (select id from <seed> except select id from <bảng thật> where <điều kiện>) x
union all
select 'real_not_in_seed', count(*) from (select id from <bảng thật> where <điều kiện> except select id from <seed>) x
```
0/0 ở cả 2 chiều mới kết luận được seed đang khớp với hiện trạng.

## 3. Seed CSV có thể làm mất độ chính xác sub-giây của timestamp — kiểm tra trước khi tin seed là "đúng tuyệt đối"

Seed `import_stag_employee_null.csv` (bản cũ trong repo) khớp **id** 100% với
bảng thật, nhưng `create_date`/`write_date` lệch ở **315/316 dòng** — không
phải sai lệch dữ liệu, mà là **CSV cũ bị cắt bớt độ chính xác** (mất phần
sau mili-giây, vd bảng thật `06:38:39.520466`, seed chỉ có `06:38:39.52`) —
gần chắc chắn do lần export CSV gốc dùng công cụ làm tròn/cắt timestamp về
mili-giây.

**Cách phát hiện nhanh 1 lệch dữ liệu là "thật" hay chỉ là mất độ chính xác**:
đừng chỉ nhìn `IS DISTINCT FROM` (chỉ nói CÓ khác, không nói khác bao nhiêu) —
trừ trực tiếp 2 giá trị timestamp để xem độ lệch:
```sql
select id, r.create_date - s.create_date as diff from ...
```
Nếu `diff` toàn cỡ mili-giây/micro-giây (không phải giờ/ngày), gần như chắc
chắn là vấn đề làm tròn ở khâu export, không phải sai lệch logic.

**Cách sửa triệt để**: export lại seed CSV **trực tiếp từ bảng thật hiện tại**
(qua `dbt show --inline "SELECT ... FROM <bảng thật> WHERE id <= 0" --output
json`, convert JSON → CSV, giữ nguyên độ chính xác gốc của Postgres) thay vì
tiếp tục dùng CSV cũ đã mất độ chính xác — seed là 1 file do dbt quản lý
(versioned, tái tạo được), không có lý do gì phải chấp nhận 1 phiên bản CSV cũ
kém chính xác hơn khi có thể tạo lại từ nguồn "sạch" ngay lúc đối chiếu.

Ghi chú công cụ: `dbt show` không hỗ trợ `--output csv` (chỉ `json`/`text`),
và không có `python3`/`node` sẵn trong môi trường Bash ở đây — dùng PowerShell
(`ConvertFrom-Json` + `[System.IO.File]::WriteAllLines(path, lines, New-Object
System.Text.UTF8Encoding $false)` để ghi UTF-8 **không BOM**, khớp encoding
file CSV gốc trong repo — `-Encoding utf8` mặc định của PowerShell 5.1 **có**
BOM, sẽ làm hỏng seed nếu dbt/Postgres COPY không xử lý BOM đúng).
