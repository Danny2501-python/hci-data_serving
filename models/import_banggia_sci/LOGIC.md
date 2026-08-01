# Logic: import_banggia_sci

Chuyển `update_import_bang_gia()` sang dbt. Output: `mart_output_import_banggia`,
alias vật lý `output_import_banggia_dbt` (xem mục "Cutover" — **chưa** ghi đè
bảng `output_import_bang_gia` thật).

## Bài toán gốc

Function đọc dữ liệu người dùng nhập tay vào bảng `import_bang_gia_chi_tiet_sci`
(qua template Excel), đối chiếu với `product_pricelist`/`product_pricelist_item`/
`product_product` hiện có trong ERP để suy ra external id còn thiếu (bảng giá,
dòng chi tiết bảng giá, dịch vụ), gắn cờ lỗi (`status_data`, `is_record_false`,
cột `"Trạng thái"`) cho từng dòng trước khi ghi vào `output_import_bang_gia`.

**Nguồn của phần chuyển đổi này**: khác với `import_dichvu_sci` (chuyển trực
tiếp từ source plpgsql `CREATE TEMP TABLE`/`RAISE NOTICE` từng bước), lần này
chỉ có **1 câu query đã dựng sẵn bằng CTE** (`input_data`, `a`, `ir_model_data_data`,
`extenal_data`, `d`, `duplicate_products`, `k`, `pp`, `g`, `p`, `output_data` +
select cuối) — không thấy thân hàm plpgsql gốc. Mapping bên dưới bám sát 1:1
theo đúng tên CTE đã có trong query đó (không đổi tên cho "dễ hiểu hơn") để
giảm rủi ro sai lệch logic khi không đối chiếu được với bản gốc. **Điều chưa
xác nhận được**: hàm `update_import_bang_gia()` thật có làm gì thêm ngoài đúng
đoạn query này không (vd. có đúng 1 lệnh `INSERT INTO output_import_bang_gia`
ở cuối như `update_import_dichvu()` làm với `output_import_dichvu`, hay còn
bước nào khác) — cần đối chiếu lại với định nghĩa hàm thật trước khi cutover.

## Nhập liệu qua seed (thay cho bảng ERP `import_bang_gia_chi_tiet_sci`)

Giống `import_dichvu_sci`: bảng `import_bang_gia_chi_tiet_sci` trước đây được
ghi trực tiếp vào Postgres bởi quy trình ngoài dbt (UI/import Excel). Pipeline
này đổi nguồn nhập liệu sang **dbt seed**:

- File: `seeds/import_bang_gia_chi_tiet_sci_seed.csv` (tên seed =
  `import_bang_gia_chi_tiet_sci_seed`, khai báo type ở `seeds/seeds.yml`).
  Hiện chỉ có dòng header (template rỗng) — chưa có dữ liệu test thật.
- `stg_ibgs_import_bang_gia_chi_tiet_sci` đọc từ
  `{{ ref('import_bang_gia_chi_tiet_sci_seed') }}` thay vì
  `source('ibgs_erp', 'import_bang_gia_chi_tiet_sci')`.
- Quy trình nhập liệu (mở seed CSV, xoá dữ liệu cũ giữ header, dán data mới,
  save "CSV UTF-8 (Comma delimited)" để không hỏng cột có dấu, `dbt seed
  --select import_bang_gia_chi_tiet_sci_seed --full-refresh` rồi `dbt run
  --select import_banggia_sci`) — xem chi tiết checklist trong
  `models/import_dichvu_sci/LOGIC.md`, áp dụng tương tự ở đây.

Khác với `import_dichvu_sci` (function gốc có `UPDATE import_danhmuc_dichvu_sci
SET ...` mutate bảng, buộc phải seed để tránh dbt mutate source), ở đây
**không có lệnh UPDATE nào** trong query được cung cấp — quyết định dùng seed
thay vì `source()` trực tiếp là để đồng nhất quy trình vận hành giữa 2 pipeline
(1 chỗ nhập liệu, không phụ thuộc quy trình ghi trực tiếp vào ERP ngoài dbt),
theo yêu cầu của người chuyển đổi, không phải bắt buộc về mặt kỹ thuật.

Kiểu cột suy ra tương tự `import_dichvu_sci`: `stt` và `brand` là `integer`
(dùng trần, so sánh trực tiếp với cột integer như `brand_etl`/mảng
`json_array_elements_text(...)::int` mà không qua cast tường minh nào trong
query), mọi cột còn lại là `varchar` (đều bị cast tường minh `::numeric`/
`::text` ở đâu đó trong query — dấu hiệu bảng thật lưu text/varchar lỏng lẻo).

Lưu ý: cột thứ 9 trong bảng gốc (vị trí `is_price_min_max` trong query gốc)
**không tồn tại với tên đó trên seed thật** — CSV thật do người dùng export có
header `"bảng giá trong khoảng"` ở đúng vị trí này (2026-08-01, phát hiện qua
lỗi `column "is_price_min_max" does not exist` khi chạy thử). Đã đổi tên cột
trong `seeds.yml`, `stg_ibgs_import_bang_gia_chi_tiet_sci`,
`int_ibgs_input_data` cho khớp. Cột này **không được dùng lại ở bất kỳ CTE nào
sau đó** trong query gốc — giữ nguyên hành vi này (port verbatim, không tự suy
diễn logic), không phải lỗi phát sinh khi chuyển đổi. Lưu ý dễ nhầm: tên cột
raw input này trùng chữ với cột **suy ra (computed)** cùng tên `"bảng giá
trong khoảng"` ở `int_ibgs_d` (từ so sánh `fixed_price - giá gốc`/`giá min`)
— đây là 2 cột khác nhau hoàn toàn (raw input vs. derived flag), chỉ trùng
tên trong schema gốc.

## Ánh xạ CTE gốc -> model dbt

| CTE gốc | Model dbt | Ghi chú |
|---|---|---|
| (đọc bảng `import_bang_gia_chi_tiet_sci`) | `stg/stg_ibgs_import_bang_gia_chi_tiet_sci` (đọc từ seed) | |
| `input_data` | `int/int_ibgs_input_data` | cast numeric, suy `product_id` |
| `a` | `int/int_ibgs_a` | join `product_product`/`product_pricelist`/`product_pricelist_item`, suy `id_bang_gia`/`id_dv`/`id_chi_tiet_bang_gia` |
| `ir_model_data_data` | `int/int_ibgs_ir_model_data_data` | lọc `ir_model_data` còn 3 model liên quan |
| `extenal_data` | `int/int_ibgs_extenal_data` | 3 lateral join lấy external id mới nhất theo brand |
| `d` | `int/int_ibgs_d` | trim external id, cờ `"bảng giá trong khoảng"` |
| `duplicate_products` | `int/int_ibgs_duplicate_products` | group theo `(pricelist_id, product_id)` trên bảng gốc (không phải `d`) |
| `k` | `int/int_ibgs_k` | gắn cờ trùng `stt` từ `duplicate_products` |
| `pp` | `int/int_ibgs_pp` | cờ thiếu `id_dv`/`id_bang_gia`/`id_chi_tiet_bang_gia`, dùng lại `ir_model_data_data` |
| `g` | `int/int_ibgs_g` | gộp cờ trùng (`k`) + cờ thiếu id (`pp`) vào `status_data` |
| `p` | `int/int_ibgs_p` | validate `applied_on`/`pricelist_id`/`fixed_price`/`%discount`, suy `id` cho dòng mới |
| `output_data` + select cuối (+ `INSERT INTO output_import_bang_gia`) | `mart/output_import_banggia` | gộp `is_record_false` + cột `"Trạng thái"` |

Mỗi model chỉ `ref()` đúng (các) CTE nó phụ thuộc trực tiếp trong query gốc,
giữ nguyên toàn bộ join/subquery lồng nhau — kể cả 2 chỗ dùng subquery lồng để
lọc `ir_model_data_data` theo `model = 'product.pricelist.item'` (trong `pp`
và lặp lại y hệt trong `p`) và block `dd`/`ibg` là subquery con ngay trong
`int_ibgs_p` (không tách model riêng vì chỉ được `p` dùng, đúng như query gốc
định nghĩa chúng làm subquery inline, không phải CTE cấp cao nhất).

## Vì sao int là `table`, không `ephemeral`

Giống `import_dichvu_sci`: `a` được `extenal_data` và `p` cùng `ref`, `g` được
`p` dùng cả trực tiếp lẫn qua subquery `dd`, `ir_model_data_data` được `pp` và
`p` cùng dùng. Nếu để `ephemeral`, dbt sẽ inline lại toàn bộ CTE cha mỗi lần
bị ref — tính lại nhiều lần một cách không cần thiết. `dbt_project.yml` đặt
`int: +materialized: table` riêng cho nhóm này (như `import_dichvu_sci`).

## Database nguồn ERP — đối chiếu new_product vs dev_staging_sci

Đối chiếu trực tiếp (query `information_schema`/`count(*)` ngày 2026-08-01) 2
database `product_product`/`product_pricelist`/`product_pricelist_item`/
`ir_model_data` (loại trừ `import_bang_gia_chi_tiet_sci` — bảng này đã chuyển
sang seed, không còn nằm trong ERP nữa) để xem `new_product` (target `dev`
đang active trong `profiles.yml`) có đủ dữ liệu không, so với `dev_staging_sci`
(target `dev` cũ, đang bị comment):

Cả 4 bảng đều là `BASE TABLE` (không phải view) ở cả 2 database, đều có cột
`brand_etl`.

**Bảng ERP gốc** (`product_product`, `product_pricelist`,
`product_pricelist_item`) — khớp tương đối tốt giữa 2 DB cho brand 1/3/4/7
(chênh lệch vài %, nhiều khả năng chỉ là độ trễ đồng bộ); brand 8 chỉ có ở
`new_product` (đúng như `import_dichvu_sci/LOGIC.md` đã ghi nhận).

**`ir_model_data` lọc đúng 3 model pipeline này dùng** (`product.pricelist`,
`product.pricelist.item`, `product.product` — xem `int_ibgs_ir_model_data_data`)
— đây là chỗ lệch nghiêm trọng, quyết định pipeline chạy đúng hay sai:

| model | brand_etl | new_product | dev_staging_sci |
|---|---|---|---|
| product.pricelist | 1 | 54 | 54 |
| product.pricelist | 3, 4, 7 | **0** | 51 mỗi brand |
| product.pricelist | 8 | 51 | 0 |
| product.pricelist.item | 1 | 24978 | 24978 |
| product.pricelist.item | 3, 4, 7 | **0** | 24481 mỗi brand |
| product.pricelist.item | 8 | 24481 | 0 |
| product.product | 1 | 15973 | 15921 |
| product.product | 3, 4, 7 | **97 / 18 / 42** (gần như trống) | ~15.4-15.7k mỗi brand |
| product.product | 8 | 16886 | 0 |

`new_product` chỉ có dữ liệu `ir_model_data` đủ dùng cho **brand 1 và brand
8** — brand 3/4/7 gần như trống hoàn toàn cho cả 3 model trên. Gap y hệt đã
ghi nhận trong `import_dichvu_sci/LOGIC.md` ("chỉ đồng bộ đầy đủ cho
brand_etl = 8"), giờ xác nhận áp dụng y hệt cho pipeline bảng giá.

**Quyết định (2026-08-01)**: làm trước **brand_etl = 1 (KangNam)**, các brand
khác (3, 4, 7) đồng bộ/backfill sau — chưa cần chạy pipeline này cho các brand
đó. Với brand 1, `new_product` **>= `dev_staging_sci`** ở mọi bảng liên quan
(`product.pricelist` 54=54, `product.pricelist.item` 24978=24978,
`product.product` 15973 vs 15921, `product_pricelist_item` gốc 41379 vs
29505) — **giữ nguyên `new_product` làm target**, không cần đổi
`profiles.yml`.

**Cập nhật sau khi chạy thử thật (2026-08-01, 71 dòng test, pricelist "Bảng
giá dịch vụ Weight Loss 2026", brand 1)**: `"pricelist_id/id"` và
`"product_id/id"` ra rỗng (không phải `NULL` — do query gốc dùng `concat()`,
hàm này coi `NULL` là chuỗi rỗng thay vì lan truyền `NULL` như `||`, nên
`concat(NULL,'.',NULL)` ra `'.'`, sau `trim(...,'.')` thành `''`) ở **toàn bộ**
71 dòng. Đối chiếu tổng số dòng khớp nhau giữa 2 DB (ở trên) **không đảm bảo
đúng những bản ghi cụ thể cần dùng đã được đồng bộ** — data mới nhất luôn là
phần có độ trễ đồng bộ cao nhất. Kiểm tra trực tiếp cho brand 1 trên
`new_product`:

- `product_pricelist`: chỉ thiếu **đúng 1 dòng** trong `ir_model_data` — chính
  là `id=141` "Bảng giá dịch vụ Weight Loss 2026" (bảng giá *mới nhất*,
  `id=140` "...2025" thì có sẵn). Toàn bộ 71 dòng test đều thuộc pricelist
  này → `"pricelist_id/id"` rỗng ở mọi dòng.
- `product_product`: thiếu **1213/15973** dòng (~7.6%) trong `ir_model_data`
  — đúng các sản phẩm/dịch vụ tạo gần đây (id lớn) → `"product_id/id"` rỗng ở
  các dòng liên quan.
- `product_pricelist_item`: thiếu **16403** dòng trong `ir_model_data` — gap
  lớn nhất, ảnh hưởng cột `id` (external id của dòng chi tiết bảng giá).

**Đây không phải lỗi của model dbt** (đã kiểm chứng: `int_ibgs_a` resolve
đúng `id_bang_gia=141`/`id_dv`/`id_chi_tiet_bang_gia` từ bảng ERP gốc, nghĩa
là bước join tên/`default_code` chạy đúng; chỉ bước tra `ir_model_data` để
lấy external id là không tìm thấy).

**Đã kiểm tra khả năng backfill từ `kn_erp` (đơn brand, nguồn xác thực nhất
theo `import_dichvu_sci/LOGIC.md`) — kết quả: không backfill được, vì `kn_erp`
cũng không có 3 bản ghi này**. Đã thử qua 2 kết nối khác nhau tới cùng DB
`kn_erp` — `report_user@10.10.10.221:54306` và `reader@10.10.10.211:54321`
(2026-08-01) — cho **kết quả giống hệt nhau** (`product_pricelist`=23,
`product_product`=11367, `product_pricelist_item`=6572, `ir_model_data`≈6.2M
ở cả 2 kết nối) → gần như chắc chắn cùng 1 database vật lý, chỉ khác
cổng/user (có thể 1 bên proxy qua bên kia), không phải nguồn độc lập nên
không cung cấp thêm dữ liệu để đối chiếu:

- `id` khớp 1:1 giữa `kn_erp` và `new_product` (đã xác nhận: cùng 1 nguồn dữ
  liệu — `product_pricelist.id=141` cùng tên "Bảng giá dịch vụ Weight Loss
  2026" ở cả 2 nơi), nhưng `ir_model_data` cho `res_id=141`
  (`product.pricelist`), `res_id=39748` (`product.product`),
  `res_id=104247` (`product.pricelist.item`) đều **không tồn tại trên
  `kn_erp`**, không riêng gì `new_product`.
- Nguyên nhân: `product_pricelist id=141` được tạo **2026-07-12**, trong khi
  pricelist *mới nhất* có `ir_model_data` trên `kn_erp` được tạo từ
  **2025-11-22** (hơn 7 tháng trước) — không pricelist nào tạo sau mốc đó có
  external id, kể cả ở nguồn gốc. Tỷ lệ thiếu trên toàn `kn_erp`:
  `product_pricelist` 2/23, `product_product` 313/11367,
  `product_pricelist_item` **5964/6572 (90.8%)**.
- Kết luận: đây là **gap vận hành ở tầng ERP** (nhiều khả năng do cơ chế gán
  external id/XML ID của Odoo — thường chỉ chạy khi record được tạo qua
  import/data file — không áp dụng cho các bản ghi tạo trực tiếp qua UI sau
  ~2025-11-22), không phải gap đồng bộ giữa các database, và **không có gì để
  copy/backfill** cho các bản ghi này ở bất kỳ database nào đã kiểm tra.

**Cập nhật quan trọng (2026-08-01, sau khi người dùng tự export thử từ UI
Odoo)**: cờ `"Cần kéo dữ liệu bảng ir_model_data"` **có cách khắc phục cụ
thể**, không phải bế tắc như đánh giá ban đầu ở trên. Khi export 1 bản ghi từ
UI Odoo với cột External ID (`pricelist_id/id`/`product_id/id`), Odoo **tự
ghi vĩnh viễn** 1 dòng vào `ir_model_data` với `module = '__export__'`, dạng
`__export__.<table>_<res_id>_<hash>` (đã xác nhận trực tiếp trên `kn_erp`:
export pricelist `id=141` và sản phẩm `id=39753` từ UI xong, query lại
`ir_model_data` thấy ngay 2 dòng `('141','product_pricelist_141_22f8fa0d',
'__export__','product.pricelist')` và tương tự cho product — khớp chính xác
giá trị hiển thị trên UI). Đây **không phải** ID ảo tính runtime — nó được
Odoo persist thật vào `ir_model_data`, và `int_ibgs_ir_model_data_data`/
`extenal_data` (đã `concat(module,'.',name)` không loại trừ `module` nào) **tự
động nhặt được**, không cần sửa gì ở tầng dbt.

Quy trình khắc phục cho các dòng bị flag: **export bản ghi liên quan từ UI
Odoo (kn_erp) → Odoo tự ghi `ir_model_data` (`module='__export__'`) → chờ job
đồng bộ định kỳ đẩy dòng đó từ `kn_erp` sang `new_product` → chạy lại
pipeline sẽ tự nhặt được**, không cần backfill thủ công. Lưu ý: `new_product`
là bản sao đồng bộ **định kỳ, không phải live** — đã kiểm chứng ngay sau khi
export, dòng `__export__.product_pricelist_141_...` có trên `kn_erp` nhưng
**chưa có** trên `new_product` (tổng thể `new_product` vẫn có ~4.3 triệu dòng
`module='__export__'` từ các lần export trước, chỉ riêng dòng vừa tạo là chưa
kịp đồng bộ) — cần biết chu kỳ job đồng bộ `ir_model_data` giữa 2 DB này (hoặc
trigger chạy tay) trước khi mong đợi pipeline thấy được dòng vừa export.

Với gap tồn đọng lớn (`product_pricelist_item` 90.8% ở `kn_erp` chưa từng
export lần nào) — không thực tế để business user export tay từng dòng; nên hỏi
đội ERP/QTDL xem có cách export hàng loạt (bulk export tất cả dòng của 1
pricelist, hoặc 1 action chạy `_export_xml_id` cho cả tập bản ghi) thay vì
từng dòng một. Nếu sau này mở rộng sang brand 3/4/7, áp dụng quy trình tương
tự — `ir_model_data` ở các brand đó thiếu nhiều hơn (xem bảng trên).

## Cutover — kế hoạch chuyển từ function sang dbt

Model hiện build ra bảng riêng `output_import_banggia_dbt` (không đụng
`output_import_bang_gia` thật) qua `{{ config(alias=...) }}` trong
`mart/output_import_banggia.sql`. Để "chốt":

1. **Trước hết, đối chiếu model này với thân hàm `update_import_bang_gia()`
   thật** (chưa xem được khi chuyển đổi) — xác nhận query gốc không bị cắt bớt
   và không có bước nào khác (UPDATE tại chỗ, INSERT nhiều bảng...) ngoài đúng
   đoạn đã port.
2. Đối chiếu dữ liệu `output_import_banggia_dbt` vs `output_import_bang_gia`
   thật sau khi chạy `update_import_bang_gia()` với cùng dữ liệu
   `import_bang_gia_chi_tiet_sci` (số dòng, `status_data`, `is_record_false`,
   `"Trạng thái"`, từng cột).
3. Bỏ dòng `config(alias=...)` để dbt build thẳng ra bảng
   `output_import_bang_gia` (cần quyền DROP/CREATE trên bảng đó).
4. Gỡ/replace lệnh gọi `update_import_bang_gia()` ở nơi đang trigger nó bằng
   lệnh `dbt run --select import_banggia_sci`.
5. Có thể xoá function `update_import_bang_gia()` sau khi xác nhận không còn
   nơi nào gọi.
