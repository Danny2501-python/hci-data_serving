# knowledge.md — Đối chiếu dữ liệu khi chuyển pandas/Python sang dbt/SQL

Phương pháp + các lỗi/bẫy ngữ nghĩa Python-vs-Postgres đã gặp khi chuyển
`get_data_product()` (pandas) sang `erp_staging/products` (dbt). Đúc kết để
dùng lại cho các bảng `stag_*` còn lại (`stag_employees`, `stag_payment_transfer`...).

## 0. Có DB thật thì đối chiếu bằng số liệu thật, đừng đoán

`dbt debug` connect được thẳng vào Postgres sống (DB `new_product`,
cùng DB chứa cả bảng ERP nguồn lẫn `stag_products` do Python ghi) — nghĩa là
**đối chiếu 1:1 với bảng thật là khả thi ngay trong lúc build**, không cần chờ
review thủ công. Quy trình đã dùng, lặp lại đến khi diff = 0:

```
1. dbt run --select <model>                     # build ra bảng alias tạm (KHÔNG đè bảng thật)
2. So row count trước                            # rẻ, phát hiện sai lệch lớn ngay
3. Diff toàn bộ cột bằng EXCEPT 2 chiều           # phát hiện lệch giá trị, không chỉ thiếu dòng
4. Với mỗi dòng lệch: pair lại bằng key ổn định   # EXCEPT + JOIN ẩu dễ tự tạo lệch giả, xem mục 5
5. Truy ra đúng 1 cột lệch -> đọc lại code Python -> sửa -> quay lại bước 1
```

Query khung ở bước 3 (đổi tên bảng + liệt kê **đủ mọi cột**, thiếu cột nào
EXCEPT sẽ không thấy lệch ở cột đó):

```sql
select 'in_real_not_dbt', count(*) from (
    select col1, col2, ... from stag_products
    except
    select col1, col2, ... from stag_products_dbt
) x
union all
select 'in_dbt_not_real', count(*) from (
    select col1, col2, ... from stag_products_dbt
    except
    select col1, col2, ... from stag_products
) y
```

`dbt show --inline "<sql>" --limit N --output json` chạy được câu bất kỳ,
không cần tạo model — tiện để thử/đối chiếu nhanh mà không làm bẩn project.
Lưu ý: nó tự bọc query trong `SELECT * FROM (...) LIMIT N`, nên **không** đặt
`LIMIT`/`ORDER BY ... LIMIT` ở câu con cuối cùng (lỗi `syntax error at or near
"limit"`).

## 1. Đừng suy đoán bảng nguồn là lịch sử hoá (snapshot) chỉ vì có cột `snapshot_date`

Giả định ban đầu (SAI): các bảng ERP nguồn (`product_product`...) có
`snapshot_date` nên tưởng là "dump toàn bộ mỗi ngày", filter
`WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM ...)` để lấy bản mới
nhất. Kết quả: bảng dựng ra chỉ có 799 dòng thay vì ~21.000.

**Sự thật**: `(id, brand_etl)` là khoá duy nhất thật sự — mỗi record ERP có
**đúng 1 dòng** trong bảng nguồn (không lặp), `snapshot_date` chỉ là "lần cuối
dòng này được touch/refresh", **không đồng bộ giữa các brand** (vd
`brand_etl=4` của `product_product` dừng cập nhật từ 2026-06-14 trong khi
brand khác vẫn cập nhật đến hôm build). Lọc theo `MAX(snapshot_date)` toàn
bảng sẽ loại bỏ sạch dữ liệu của brand nào "chưa được touch" gần đây nhất.

**Cách kiểm tra đúng trước khi quyết định lọc hay không**: đếm
`(khoá tự nhiên) -> COUNT(*)` toàn bảng, xem có dòng nào > 1 không:

```sql
with c as (select id, brand_etl, count(*) n from <table> group by id, brand_etl)
select n, count(*) how_many from c group by n order by n
```
Nếu tất cả `n = 1` → không có lịch sử hoá, **không filter gì cả**, `SELECT *`
là đủ.

## 2. NULL trong SQL là logic 3 giá trị — pandas `.isin()`/`.fillna()` thì không

`is_difn = product_id.isin(ls_pid) | default_code.fillna('').isin(ls_dc)` —
chú ý `.fillna('')` **trước** `.isin()`: pandas luôn trả `True`/`False` dứt
khoát, không bao giờ `NaN`.

Dịch thẳng sang SQL (SAI): `product_id IN (...) OR default_code IN (...)`.
Khi `default_code IS NULL`, `default_code IN (...)` = `NULL` (không phải
`false`) → `is_difn` = `NULL` → **cả 2 nhánh** `WHERE is_difn` và
`WHERE NOT is_difn` đều loại dòng đó (`NOT NULL` vẫn là `NULL`, không phải
`true`) → dòng biến mất khỏi mọi nhánh, không rơi vào đâu cả.

**Cách sửa**: bọc `COALESCE(<biểu thức>, false)` ở bất kỳ điều kiện boolean
nào về sau có dùng theo kiểu "đủ 2 nhánh bù nhau" (`WHERE x` / `WHERE NOT x`) —
không được để nó có khả năng ra `NULL`.

## 3. `PARTITION BY`/`GROUP BY` gộp mọi NULL vào 1 nhóm — pandas `groupby()` (mặc định `dropna=True`) thì loại hẳn dòng có key NaN ra khỏi phép gộp

`df.groupby('default_code')['v'].transform('max')` — với dòng có
`default_code` là `NaN`, pandas **không tính nhóm chung** cho các dòng NaN đó
(mỗi dòng NaN coi như không thuộc nhóm nào, `transform` trả `NaN` cho toàn bộ
chúng, **độc lập với nhau**).

Dịch sang `MAX(...) OVER (PARTITION BY default_code)` (SAI): Postgres coi mọi
`NULL` của `default_code` là **cùng 1 partition** — hệ quả: hàng nghìn sản
phẩm không liên quan (chỉ vì cùng thiếu `default_code`) bị gộp chung 1
`MAX()`, ra cùng 1 bộ id → bước dedup phía sau collapse nhầm hàng loạt dòng
khác nhau xuống còn 1 dòng.

**Cách sửa**: không dùng window `PARTITION BY` cho phép gộp có khả năng NULL
key kiểu "loại trừ" này — chuyển qua `GROUP BY` + `LEFT JOIN` (equi-join
chuẩn: `NULL = NULL` là `false`/`unknown`, tự động không match — đúng ngữ
nghĩa "loại dòng NULL ra khỏi nhóm" của pandas):

```sql
-- Sai: window partition gộp mọi NULL default_code làm 1
select *, max(case when br='pr' then product_id end) over (partition by default_code) as pr_id
from t

-- Đúng: GROUP BY rồi LEFT JOIN lại — NULL = NULL không match, mỗi dòng NULL độc lập
with agg as (select default_code, max(product_id) bcast from t where br='pr' group by default_code)
select t.*, agg.bcast as pr_id from t left join agg on agg.default_code = t.default_code
```

Ghi chú: bước dedup cuối (`drop_duplicates` trên tổ hợp các cột id đã tính)
**vẫn giữ nguyên `ROW_NUMBER() OVER (PARTITION BY ...)`** bình thường — pandas
`drop_duplicates` (khác `groupby`) coi `NaN == NaN` là trùng, đúng với ngữ
nghĩa `PARTITION BY` gộp NULL của Postgres. Chỉ riêng bước *broadcast theo
group* (tương đương `groupby().transform()`) mới cần đổi sang `GROUP BY` +
`LEFT JOIN`.

## 4. `pandas.Series.sum()` trên nhóm toàn `NaN` trả về `0`, `SUM()` trong Postgres trả về `NULL`

`dfgr = dffkpi.groupby('product_id')['kpi_point'].sum()` — nếu 1 `product_id`
chỉ có các dòng `kpi_point` toàn `NaN` sau khi merge (vd `product_id_kn` trỏ
tới 1 id không tồn tại), `.sum()` mặc định (`skipna=True`) trả **`0.0`**, không
phải `NaN`. Đây là hành vi gây nhầm lẫn nổi tiếng của pandas — khác hẳn
`.mean()`/`.max()`/`.min()` (các hàm đó trả `NaN` cho nhóm toàn `NaN`).

Postgres `SUM()` trên nhóm toàn `NULL` (kể cả 0 dòng) trả **`NULL`**.

**Cách sửa**: `COALESCE(SUM(x), 0)` bất cứ khi nào dịch `.groupby().sum()` từ
pandas — không dịch mù theo bản năng "SUM thì cứ SUM".

## 5. Tự đối chiếu (diff) cũng có thể tạo lệch giả — chọn khoá join đủ chọn lọc

Khi so 2 bảng bằng `JOIN`/`FULL JOIN` để in ra *nội dung* dòng lệch (khác với
`EXCEPT` ở bước 3, vốn tin cậy vì so nguyên tuple), 2 lỗi hay gặp:

- **`a.col = b.col` không match khi cả 2 đều `NULL`** (vd join theo
  `default_code` mà default_code null) → tưởng dòng "chỉ có ở 1 bên" trong khi
  thực ra khớp nhau, chỉ là join fail. Dùng `IS NOT DISTINCT FROM` (lưu ý:
  `FULL JOIN ... ON a IS NOT DISTINCT FROM b` **không được** Postgres hỗ trợ —
  báo lỗi "FULL JOIN is only supported with merge-joinable or hash-joinable
  join conditions" — phải đổi qua `COALESCE(a, sentinel) = COALESCE(b, sentinel)`).
- **Khoá join không đủ chọn lọc khi 1 `default_code` có nhiều dòng hợp lệ**
  (case `dfmap3`: 1 default_code ra nhiều dòng, mỗi dòng giữ id riêng của
  brand mình) → join theo default_code đơn thuần bị nhân bản chéo
  (fan-out), 2 dòng *đều đúng* nhưng bị ghép sai cặp, in ra "lệch" giả (thấy
  `hh_id`/`sci_id` như bị hoán đổi giữa 2 bên dù dữ liệu 2 bên giống hệt nhau).

**Cách kiểm tra chắc chắn 1 nhóm dòng có thật sự lệch hay không**: bỏ hẳn
`JOIN`, lấy toàn bộ dòng liên quan ở **cả 2 bảng riêng biệt** rồi nhìn bằng
mắt (`WHERE default_code = 'X'` trên từng bảng, `UNION ALL` lại), hoặc thêm
`ROW_NUMBER() OVER (PARTITION BY <toàn bộ cột định danh> ORDER BY <cột ổn
định>)` vào key join để tách các dòng trùng khoá thay vì để chúng tự do
match chéo nhau.

## 6. `.` trong regex Postgres khớp cả `\n`; Python `re` (mặc định, không `DOTALL`) thì không

Case thực tế: `product` (tên dịch vụ) chứa `\n` giữa chuỖi
(`"Phun xăm toàn phần \n(CB+NC+CS) - Chưa bao gồm điêu khắc"`). Code gốc:
```python
df['product'].str.match('.*(xóa (hình )?xăm|phun (môi|mày|mí|thêu)|điêu khắc|hair stro).*', case=False)
```
`str.match` dùng `re.match` (khớp từ đầu chuỗi), và **`.` mặc định không khớp
`\n`** trong Python `re` (cần cờ `re.DOTALL`). Vì vậy `.*` ở đầu pattern
**không thể vượt qua** dấu `\n` để "nhìn thấy" cụm "điêu khắc" nằm ở dòng thứ
2 → kết quả gốc: **không match**.

Dịch sang `product ~* '(...)'` (SAI): Postgres ERE mặc định **`.` khớp cả
`\n`** (không có khái niệm "single-line" ngầm định như Python) — nhưng vấn đề
ở đây thậm chí không cần đến `.`: `~*` vốn là tìm **kiếm chuỗi con** (substring
search), tự nó xuyên qua `\n` bình thường vì `\n` chỉ là 1 ký tự như bao ký tự
khác đối với thuật toán tìm kiếm chuỗi con → match "điêu khắc" dù nó nằm sau
`\n` → SAI so với bản gốc.

**Cách sửa**: cắt chuỗi tìm kiếm về đúng "dòng đầu tiên" trước khi search, mô
phỏng đúng giới hạn mà `.*` không-DOTALL của Python tạo ra:
```sql
split_part(product, chr(10), 1) ~* '(...)'   -- thay vì product ~* '(...)'
```
Áp dụng cho **mọi** biểu thức dịch từ `.str.match('.*(...).*' , case=False)`
trong pandas (không áp dụng cho các điều kiện regex vốn đã chạy trực tiếp
trong câu SQL gốc qua `psycopg2`, như các `CASE WHEN pc.name ~* ...` trong
`query_pd` — những chỗ đó vốn dĩ đã là Postgres-native, không có gì để dịch).

## 7. `df.to_csv()` → `COPY ... CSV` biến chuỗi rỗng `''` thành `NULL`

`insert_data_to_db()` ghi DataFrame ra CSV tạm (`df.to_csv(...)`, không ép
`QUOTE_ALL`) rồi `COPY <table> FROM STDIN WITH CSV HEADER`. Theo đặc tả CSV
của Postgres, **1 field rỗng không có dấu ngoặc kép** khi COPY được hiểu là
`NULL`, không phải chuỗi rỗng — trong khi pandas `to_csv` mặc định
(`QUOTE_MINIMAL`) không quote 1 chuỗi rỗng (không có ký tự đặc biệt cần quote).

Hệ quả: bất kỳ cột `text`/`varchar` nào tính ra `''` (vd `TRIM(pt.name)` khi
`pt.name` là chuỗi trắng/rỗng) sẽ **luôn bị nạp thành `NULL`** trong bảng thật
— dù về mặt SQL thuần tuý `TRIM('')` đúng là `''`, không phải `NULL`.

**Cách sửa**: bọc `NULLIF(<cột text>, '')` cho **toàn bộ cột varchar** ở SELECT
cuối cùng của mart model (không chỉ cột có `TRIM`/`REGEXP_REPLACE` — cột nào
cũng có thể `''` ngay từ nguồn) để mô phỏng đúng hành vi ngầm định của pipeline
Python cũ. Đây là hành vi **chung cho mọi bảng `stag_*`** do Python ghi qua
cùng cơ chế `insert_data_to_db()` — không riêng gì `stag_products`, cần áp
dụng lại khi chuyển các bảng còn lại.

## 8. Gap đồng bộ ERP làm mất nguyên cả nhóm sản phẩm khỏi output (không phải lỗi logic dbt) — backfill bằng seed, không vá thẳng bảng mart

Đối chiếu `stag_products` giữa target `new_product` và DB `sandbox`
(2026-08-11) phát hiện **9.209 sản phẩm brand EHC** (`default_code` tiền tố
`EHC*`, `product_category = 'SAN PHAM'`) có mặt ở `sandbox` nhưng **biến mất
hoàn toàn** khỏi `stag_products` trên target `new_product`.

**Gốc rễ**: không phải lỗi SQL. `int_stps_base.sql` gộp đủ 5 brand
(`brand_etl in (1,3,4,7,8)`), nhưng nhánh `dfo` của `int_stps_product_map.sql`
(áp dụng cho `product_id <= 31842`, tương đương `dfmap1` trong Python) **chỉ
giữ dòng của brand `kn` (`brand_etl=1`) làm output — dòng brand khác cùng
product_id cũ bị loại bỏ hẳn**, không rơi vào `dfmap3` (nhánh đó chỉ nhận
`product_id > 31842`). Kiểm chứng trực tiếp trên `public.product_product` của
`new_product`: cả 9.209 id đều có dòng `brand_etl` 4/7/8, **0/9.209** có dòng
`brand_etl=1` — tức bảng ERP nguồn (`product_product`) trong `new_product`
đang thiếu cục bộ đúng phần brand KangNam cho nhóm sản phẩm này (gap đồng bộ
ERP từ nguồn, không phải do model dbt viết sai) — khớp với việc `new_product`
vốn là bản sao đồng bộ định kỳ, không live.

**Cách xử lý đã chọn — KHÔNG vá trực tiếp `stag_products`**: bảng này là
mart `materialized: table`, mỗi `dbt run` sẽ DROP/CREATE lại toàn bộ từ
`int_stps_product_map`, nên `INSERT` tay vào `stag_products` sẽ mất sạch ở
lần chạy kế tiếp. Thay vào đó:

1. Seed `stag_product_backfill_sandbox` (`seeds/stag_product_backfill_sandbox.csv`,
   config ở `seeds/seeds.yml`) chứa đúng 9.209 dòng đã export từ `sandbox`,
   schema khớp cột output cuối cùng của `stag_products`.
2. `stag_products.sql` `union all` thêm seed này vào sau `combined` (kết quả
   `int_stps_product_map`), có **anti-join theo `product_id`**
   (`where product_id not in (select product_id from combined ...)`) — một
   khi `new_product` được đồng bộ đủ `brand_etl=1` cho các id này, dòng thật
   từ `combined` sẽ tự động "thắng" và dòng seed tự động không còn được chọn,
   không cần dọn tay.
3. `dbt run` (không phải `dbt build`) **không tự load seed** — DAG
   (`data_ops/dags/dbt/data_serving_erp_staging_dag.py`) phải có task
   `dbt seed --select stag_product_backfill_sandbox` chạy **trước** task
   `dbt run --select tag:erp_staging`.

Áp dụng lại được cho mọi gap đồng bộ ERP dạng "thiếu hẳn 1 brand/nhóm id" ở
các bảng `stag_*` khác: seed + union + anti-join theo khoá tự nhiên, không
đụng vào bảng ERP nguồn lẫn bảng mart.

## 9. Thêm 1 điều kiện `OR` vào giữa `CASE WHEN` không đảm bảo có tác dụng — phải kiểm tra dữ liệu thật khớp nhánh nào TRƯỚC nó

Case thực tế (2026-09-10, `view_stag_products.sql` cột `product_group`):
thêm `OR (product_category = 'GIẢM BÉO KHÔNG PT')` vào nhánh `BÉO ĐA CHUYÊN
KHOA` (nhánh thứ 5 trong CASE) *nhìn qua tưởng đúng* — category đó tồn tại
thật, không viết sai regex/tên. Nhưng verify bằng cách join thẳng
`sh_medical_health_center_service` mới phát hiện: toàn bộ dòng thuộc category
này có `his_service_type IN ('Laser','Spa')` — trùng đúng điều kiện của nhánh
thứ **2** (`BEAUTY & SPA`), đứng **trước** nhánh 5. `CASE WHEN` dừng ở nhánh
đầu tiên khớp, nên điều kiện mới thêm ở nhánh 5 **không bao giờ được xét
tới** — sửa xong tưởng đã fix nhưng số liệu không đổi.

**Bài học:** khi thêm 1 `OR`/nhánh mới vào `CASE WHEN` đã có sẵn nhiều nhánh,
không đủ để kiểm tra "điều kiện mới có đúng không" — phải tự hỏi thêm: **dữ
liệu thoả điều kiện mới có khả năng thoả luôn 1 điều kiện của nhánh nào đứng
TRƯỚC nó không?** Cách kiểm chứng chắc chắn: join thẳng ra các cột dùng trong
mọi nhánh phía trước (ở đây là `his_service_type`) cho đúng tập dữ liệu vừa
thêm điều kiện, xem có dòng nào khớp nhánh trước không — nếu có, phải dời
nhánh mới/sửa lên trước nhánh đó, không chỉ thêm `OR` tại chỗ.

Tổng quát hơn: đây là hệ quả của **short-circuit theo thứ tự khai báo** —
giống hệt bẫy khi thêm 1 `ELIF`/`if` mới vào giữa chuỗi `if/elif` đã có trong
bất kỳ ngôn ngữ nào, không riêng SQL. Luôn liệt kê lại toàn bộ điều kiện của
**các nhánh đứng trước** nhánh vừa sửa, không chỉ nhìn nhánh đang sửa.
