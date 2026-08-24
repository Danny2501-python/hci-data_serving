# Logic: erp_staging/employees

Chuyển logic tạo bảng `stag_employees` (Python/pandas trong Airflow DAG
`quentk_1_stag_crm_New_sys.py`, hàm `get_data_employee()` + `write_stag_employees()`)
sang dbt. Output: `mart_stag_employees`, alias vật lý `stag_employees_dbt` (chưa
ghi đè bảng `stag_employees` thật — xem `erp_staging/products/LOGIC.md` mục
"Cutover" cho quy trình chung, áp dụng y hệt cho bảng này).

Đối chiếu ngày 2026-07-24: khớp **tuyệt đối 100%** với `stag_employees`
(4.536 dòng, 40 cột, `EXCEPT` 2 chiều = 0/0). Xem `knowledge.md` cho phát
hiện quan trọng nhất của lần đối chiếu này: **1 phần dữ liệu của bảng thật
không tái tạo được từ logic SQL**, phải `UNION ALL` với seed — seed
`import_stag_employee_null` đã được export lại từ bảng thật để giữ nguyên
độ chính xác sub-giây của timestamp (xem `knowledge.md` mục 3).

---

## Nguồn dữ liệu chính: `hr_employee` (brand_etl = 7, "sci" — bản ghi tổng của Tập đoàn)

Base query join thêm: công ty (`m_res_company`), thương hiệu (`res_brand`),
phòng ban (`hr_department` qua bảng map `stag_phongbanphanquyen_id`), chức vụ
(`hr_job`), nhóm chức vụ (`hr_group_job`), team (`hr_team`), khối
(`hr_department_sector`) — toàn bộ join theo cặp `(id, brand_etl)`.

Có 2 join trong code Python gốc (`res_users`, `res_partner`) **không SELECT ra
cột nào** — kiểm tra kỹ thấy chúng là dead join thuần tuý (không ảnh hưởng kết
quả vì key `id` vốn đã duy nhất, không fan-out), nên **bỏ hẳn** khỏi
`int_stem_base.sql`, không dịch lại.

`WHERE rc.brand_etl = 7 AND rb.brand_etl = 7` biến 2 `LEFT JOIN` (company,
brand) thành **INNER JOIN trên thực tế** — nhân viên nào không có company/brand
hợp lệ sẽ bị loại hẳn, không phải NULL. Dịch thẳng thành `INNER JOIN` cho rõ ý,
tương đương 100% hành vi gốc.

## Chuẩn hoá phòng ban (department)

```
he.department_id
  -> spi.department_id (stag_phongbanphanquyen_id, bảng map thủ công)
  -> spi.new_name
  -> hdc.name (tên phòng ban chuẩn hoá, chỉ tính brand_etl IN (0,7), lấy id lớn nhất nếu trùng tên)
  -> department_id (output) = COALESCE(hdc.id, he.department_id)
  -> hd.name (brand_etl = 7) = department (output)
```
`old_department_id` = `he.department_id` gốc, chưa chuẩn hoá — giữ để đối chiếu.

## `phongbanphanquyen` — override tạm 1 trường hợp cụ thể

```
= 2602 nếu (department_id = 2635) HOẶC (id = 3337) HOẶC (company_id = 4 VÀ department_id = 2599)
= department_id (đã chuẩn hoá) trong các trường hợp còn lại
```
Comment gốc: "xử lý tạm phân quyền phòng ban BS Đoàn Hùng Thịnh (BV KNSG -
Chuyên khoa PTTM)" — override cứng cho 1 nhân sự/phòng ban cụ thể, không phải
rule tổng quát.

## Map id nhân viên sang brand kn/pr/hh (`{br}_id`, `{br}_user_id`)

Match theo `employee_code` với nhân viên cùng mã ở từng ERP brand riêng
(`hr_employee` filter theo `brand_etl` = 1/kn, 3/pr, 4/hh), lấy `MIN(id)`,
`MIN(user_id)` nếu 1 `employee_code` khớp nhiều dòng.

**Backfill cho tài khoản admin/hệ thống**: nếu không match được employee_code
(`{br}_user_id IS NULL`) **và** `COALESCE(user_id, 0) < 10` (chú ý:
`user_id IS NULL` cũng tính là "admin" ở đây, không chỉ id nhỏ — đây là hành vi
gốc, không phải cách diễn giải hợp lý duy nhất, giữ nguyên để khớp dữ liệu),
thì gán `{br}_id` = chính `id`, `{br}_user_id` = chính `user_id` — coi tài
khoản admin/system là "dùng chung" giữa các brand, không cần map qua
employee_code.

## `job_lv2` — dùng seed thay vì hard-code lại dictionary

Code Python gốc định nghĩa `dict_job`/`dict_emp` (danh sách cứng id nhân sự →
nhóm chức danh bác sĩ KNHN) ngay trong hàm. Dữ liệu này đã tồn tại sẵn dưới
dạng seed **`seeds/import_stag_employee_doctor.csv`** (cột `id, employee,
job_id, job_name` — `job_id` ở đây là id 1..5 của nhóm chức danh, **không phải**
`hr_job.id` thật, dễ nhầm) — dùng thẳng seed này qua
`LEFT JOIN ... ON import_stag_employee_doctor.id = he.id`, `job_lv2 =
COALESCE(job_name, job)`, không hard-code lại dictionary trong SQL.

## Dedup theo `employee_code`

```sql
ROW_NUMBER() OVER (PARTITION BY employee_code ORDER BY active ASC, create_date ASC) = 1
```
Lưu ý ngược trực giác: `active ASC` xếp `false` (đã nghỉ việc) **trước**
`true` (đang làm) — nghĩa là nếu 1 `employee_code` có cả bản ghi active lẫn
inactive, bản ghi **inactive** được giữ lại (không phải bản ghi đang hoạt
động!). Đây là hành vi gốc của code Python (`ascending=[True, True]` trên
`['active', 'create_date']`), giữ nguyên dù nhìn có vẻ ngược đời — không tự ý
"sửa" thành `DESC` vì đó sẽ là đổi logic nghiệp vụ, không phải sửa lỗi dịch
SQL.

## Seed `import_stag_employee_null` — phần dữ liệu KHÔNG SINH RA được từ logic trên

`write_stag_employees()` chỉ chạy `DELETE FROM stag_employees WHERE id > 0`
mỗi lần build — các dòng `id <= 0` (316 dòng: tài khoản hệ thống/"Sync", nhân
sự thiếu dữ liệu ERP...) **không bao giờ bị xoá hay ghi lại** bởi pipeline
Python, chỉ tồn tại nhờ 1 lần import CSV thủ công trước đây (ngoài phạm vi DAG).
Không có logic SQL/Python nào tái tạo được tập dữ liệu này — bắt buộc phải
`UNION ALL` với seed `import_stag_employee_null` trong `mart/stag_employees.sql`.

Có seed thứ 2 tương tự (`seeds/import_employee.csv`, 2 dòng) — đây là data từ
1 khối `data_fix = [...]` nằm **trong docstring** (chuỗi `'''...'''` không gán
biến, không return) của `get_data_employee()` — tức là **code chết, chưa bao
giờ chạy**. Seed này KHÔNG dùng trong model — `import_stag_employee_null` đã
bao phủ đúng và đủ (đối chiếu 0 lệch cả 2 chiều với tập `id<=0` của bảng thật).

## Cutover

Giống hệt quy trình ở `erp_staging/products/LOGIC.md`: bỏ `config(alias=...)`
trong `mart/stag_employees.sql`, xoá task Airflow `task_1_stag_employees`
(`write_stag_employees`). Vì phần dữ liệu `id<=0` đến từ seed (dbt-managed,
không đổi theo ERP sống), **không cần đối chiếu lại phần đó** trước cutover —
chỉ cần re-run đối chiếu phần `id>0` (sinh từ ERP) ngay trước khi cutover, như
với `stag_products`.

## mart/view_stag_employees_user.sql — port view thủ công `public.view_stag_employees_user`

Port 1:1 view Postgres thủ công cùng tên đang chạy thật trong DB `new_product`
(không do dbt quản lý, DDL gốc do anh yêu paste trực tiếp). `materialized='view'`,
alias `view_stag_employees_user`, dùng `ref('stag_employees')` (không phải
`source()`) → dbt tự xếp model này chạy **sau** khi bảng `stag_employees` build
xong.

- UNION ALL 5 nhánh theo `brand_etl` (1=kn, 3=pr, 4=hh, 8=thv, 0=chính
  id/user_id gốc của bảng `stag_employees`) — không cần join thêm bảng nào
  khác (khác `view_stag_products`, view này chỉ đọc từ 1 bảng).
- `user_id` mọi nhánh đều `NULLIF(..., 0)` — giữ nguyên như view gốc (id user
  = 0 coi như NULL).
- Đã `dbt compile --select view_stag_employees_user` thành công (2026-08-11).
  **Chưa** `dbt run` — cần xác nhận trước vì đây là thay đổi schema DB
  production (xem `erp_staging/products/LOGIC.md` mục `view_stag_products`
  cho cùng lưu ý này, áp dụng chung cho cả 2 view).
