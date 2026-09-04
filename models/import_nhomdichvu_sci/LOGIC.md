# Logic: import_nhomdichvu_sci

Chuyển câu query trong `Readme.md` (đã có sẵn dạng CTE, không có function
plpgsql gốc kèm theo) sang model dbt. Output: `mart_output_import_nhomdichvu`,
alias vật lý `output_import_nhomdichvu_dbt` (xem mục "Chưa xác nhận" — **chưa**
ghi đè bảng đích thật).

## Bài toán gốc

Đối chiếu dữ liệu người dùng nhập tay (`import_danhmuc_nhomdichvu_sci`: mã
`code`, tên `name`, tên brand `"brand_id/name"` của từng "nhóm dịch vụ") với
`sh_medical_health_center_service_category`/`product_category` hiện có trong
ERP để suy ra external id còn thiếu, phát hiện nhóm dịch vụ bị trùng
(`is_prod_cat_duplicate`), gắn cờ trạng thái (`data_status`, `is_record_false`)
cho từng dòng.

## Nhập liệu qua seed (thay cho bảng ERP `import_danhmuc_nhomdichvu_sci`)

Giống `import_dichvu_sci`/`import_banggia_sci`: seed
`seeds/import_danhmuc_nhomdichvu_sci_seed.csv` (name
`import_danhmuc_nhomdichvu_sci_seed`, khai báo ở `seeds/seeds.yml`). Chỉ khai
báo 3 cột `code`/`name`/`"brand_id/name"` vì đó là toàn bộ những cột câu query
gốc trong `Readme.md` thực sự dùng tới (bảng thật có thể còn cột khác — cần
đối chiếu CSV export thật trước khi nạp thêm dữ liệu khác lô này).
`stg_indvs_import_danhmuc_nhomdichvu_sci` đọc từ
`{{ ref('import_danhmuc_nhomdichvu_sci_seed') }}` thay vì
`source('indvs_erp', 'import_danhmuc_nhomdichvu_sci')`.

**Dữ liệu nạp 2026-09-03** (4 dòng, dự án "Cấy tóc thổ nhĩ kỳ"): lấy từ sheet
"Mã nhóm" trong `Import_master_data/2026-09-03/Cấy tóc thổ nhĩ kỳ/0. TEMPLATE
BẢNG GIÁ CẤY TÓC TNK _ 2026.xlsx`. Sheet gốc có 4 cột: "NHÓM DỊCH VỤ" (tên
nhóm dịch vụ), "MÃ NHÓM" (đã ở dạng `__import__.<code>` — **không** dùng cột
này làm `code` vì đây là định dạng `id` do `int_indvs_output_data` tự suy ra
`concat('__import__.', code)`, không phải input thô), 1 cột không tên chứa mã
thô (`QTTNK0001`...) — dùng cột này làm `code`, và 1 cột không tên chứa ghi
chú ("Thêm mới _ 31/09/2026") — bỏ qua, không đưa vào seed vì không cột CTE
nào trong query gốc dùng tới. Cột `"brand_id/name"` không có sẵn trong sheet —
theo yêu cầu người dùng dùng brand **Kangnam** cho cả 4 dòng, đã tra
`res_brand` (đọc, không sửa) xác nhận tên chính xác `name = 'Kangnam'`
(`id = 1`).

**Kết quả tra cứu ERP cho lô 4 dòng này (2026-09-03, đọc `dev`/`new_product`,
không sửa dữ liệu)**: cả 4 `code` (`QTTNK0001`-`QTTNK0004`) đều **chưa tồn
tại** trong `product_category` → toàn bộ 4 dòng là "Nhóm dịch vụ mới"
(`is_prod_cat_new = true`, `product_cat_id/id = null`,
`id = concat('__import__.', code)`). `brand_id/id` của Kangnam (`res_brand.id
= 1`) từ `ir_model_data` (`model = 'res.brand'`) = `sci_brand.res_brand_kn`.
File output đầy đủ 12 cột (tính tay theo đúng logic mart, không chạy
`dbt seed`/`dbt run` vào DB) đã lưu tại
`Import_master_data/2026-09-03/Cấy tóc thổ nhĩ kỳ/3. Output
import_nhomdichvu_sci - Cấy tóc TNK 2026.xlsx`.

## File import dịch vụ (sang Odoo) cho lô "Cấy tóc thổ nhĩ kỳ"

Không thuộc pipeline `import_nhomdichvu_sci` (đây là dịch vụ, thuộc
`import_dichvu_sci`) nhưng ghi chung vào đây vì cùng nguồn workbook/lô dữ
liệu. Nguồn thật: sheet `QT_2026` trong `0. TEMPLATE BẢNG GIÁ CẤY TÓC TNK _
2026.xlsx` (4 dòng: HT-1, HT-2, BT-1, ET-1) — **không** dùng sheet "Gửi hệ
thống" làm nguồn vì 3 dòng mẫu trong đó là dữ liệu rác (dịch vụ "Giảm mỡ Lipo
360" không liên quan); sheet "Gửi hệ thống" chỉ dùng làm **format cột đích**
(39 cột + 1 cột ghi chú không tên, đúng chuẩn Odoo import — QT_2026 có thêm
các cột KPI tạm `Điểm cũ`/`Chênh lệch`/`Ngày cập nhật`/... không thuộc format
này, đã loại bỏ).

Đã transform 2 chỗ trước khi xuất file:
- `service_category/id`: QT_2026 để mã thô (`QTTNK0001`/`QTTNK0003`/
  `QTTNK0004`) — đổi thành external id `__import__.<code>` theo đúng kết quả
  đã tính ở `output_import_nhomdichvu_sci` (mục trên).
- `uom_id/id`/`uom_so_id/id`/`uom_po_id/id`: QT_2026 ghi chữ "Package" (không
  phải external id, và **không tồn tại** đơn vị tính tên "Package" hay "Lần"
  trong `uom_uom` — đã kiểm tra toàn bộ 424 tên). Anh xác nhận đơn vị đúng là
  **"Gói"** — tra được `uom_uom.id = 843` (tên khớp chính xác "Gói", không
  hậu tố số lượng), external id qua `ir_model_data`
  (`model = 'uom.uom'`) = `__import__.product_uom_categ_unit_21`. Đã điền cả
  3 cột `uom_.../id` bằng external id này, và sửa `uom_id/name` từ "Package"
  thành "Gói".

Các cột còn để trống (giữ đúng như QT_2026, không tự suy diễn):
`institution/id`, `service_department/id`, `service_room/id`, `exam_room/id`,
`type_product_crm`, `is_no_specialty`, `is_no_phonecall`, `is_input_num`,
`lab_type_ids/id`, `imaging_type_ids/id`.

File kết quả: `Import_master_data/2026-09-03/Cấy tóc thổ nhĩ kỳ/4. Import
dichvu_sci - Cấy tóc TNK 2026.xlsx` (sheet "Gửi hệ thống", 40 cột, 4 dòng) —
file mới, không ghi đè file `0. TEMPLATE...` gốc. (Người dùng sau đó đổi tên
file bỏ số thứ tự "4." — file hiện ở đường dẫn cùng thư mục, tên
`import dichvu_sci - Cấy tóc TNK 2026.xlsx`.)

**Sửa lỗi sau khi thử import thật vào Odoo (2026-09-03)**:
- `categ_id/id` để trống bị Odoo báo "Missing required value for the field
  'categ_id'" ở cả 4 dòng — field bắt buộc. Đã điền hằng số
  `shealth_all_in_one.sh_services` (đúng giá trị `categ_id/id` dùng trong
  seed `import_dichvu_sci` cũ, xem sample trong
  `seeds/import_danhmuc_dichvu_sci_seed.csv`).
- `anesthetist_type = 'Local Anesthesia'` (tiếng Anh, copy nguyên từ QT_2026)
  sai — đây là field selection nội bộ, phải dùng đúng label tiếng Việt hệ
  thống đang dùng. Đã tra `ir_model_fields_selection` (field
  `anesthetist_type`, thuộc `sh_medical_health_center_service`): giá trị kỹ
  thuật `tetaicho` ↔ label **"Tê tại chỗ"** (đối chiếu cách `surgery_type`
  cũng dùng label tiếng Việt trực tiếp như `Tiểu phẫu`/`Đại phẫu`, không phải
  giá trị kỹ thuật). Các label khác cùng field (tham khảo nếu sau này có dịch
  vụ khác loại vô cảm): `me` = "Gây mê", `boite` = "Bôi tê", `te` = "Gây tê",
  `tien_me` = "Tiền mê".

## Ánh xạ CTE gốc -> model dbt

| CTE gốc | Model dbt | Ghi chú |
|---|---|---|
| (đọc bảng `import_danhmuc_nhomdichvu_sci`) | `stg/stg_indvs_import_danhmuc_nhomdichvu_sci` (đọc từ seed) | chỉ 3 cột `code`/`name`/`"brand_id/name"` |
| `data_nhomdichvu` (gồm `a`/`b`/`c` lồng bên trong) | `int/int_indvs_data_nhomdichvu` | giữ nguyên cấu trúc lồng gốc trong 1 model — `a`/`b`/`c` chỉ dùng nội bộ CTE này, không CTE nào khác trong query gốc ref trực tiếp |
| `nhom_dichvu` | `int/int_indvs_nhom_dichvu` | join `data_nhomdichvu` + tra `brand_id` từ `res_brand`/`ir_model_data` |
| `output_data` | `int/int_indvs_output_data` | suy `id` = `concat('__import__.', code)` khi chưa có `product_category` khớp `code` |
| `note_data` | `int/int_indvs_note_data` | cờ `is_prod_cat_new` |
| `type_data_nhomdichvu` | `int/int_indvs_type_data_nhomdichvu` | gộp `data_status`; `output_data` được ref lại 2 lần (trực tiếp `nd` + subquery `f`) |
| `output_nhomdichvu` + select cuối | `mart/output_import_nhomdichvu` | gộp `is_record_false` |

Mỗi model chỉ `ref()` đúng (các) CTE nó phụ thuộc trực tiếp trong query gốc,
giữ nguyên toàn bộ join/subquery lồng nhau, không đổi tên cột/alias để giảm
rủi ro sai lệch logic khi không có bản gốc (function plpgsql) để đối chiếu.

## Vì sao `int` là `table`, không `ephemeral`

Giống 2 pipeline liền kề: `output_data` được `note_data` và
`type_data_nhomdichvu` (2 lần: trực tiếp `nd` + subquery `f`) cùng ref. Nếu để
`ephemeral`, dbt sẽ inline lại toàn bộ CTE cha mỗi lần bị ref — tính lại nhiều
lần không cần thiết. `dbt_project.yml` đặt `int: +materialized: table` riêng
cho nhóm này.

## Chưa xác nhận

- Chưa có bảng ERP hoặc function plpgsql gốc nào để đối chiếu — chỉ có 1 câu
  query CTE trong `Readme.md`. Mapping bám sát 1:1 tên CTE gốc, không tự suy
  diễn thêm logic.
- Tên bảng đích thật (tương đương `output_import_bang_gia`/
  `output_import_dichvu`) và có hay không 1 lệnh `INSERT`/`UPDATE` nào khác
  ngoài đúng đoạn query đã port — chưa xác nhận được. Mart hiện alias tạm
  `output_import_nhomdichvu_dbt`, chưa ghi đè bảng thật.
- Cấu trúc cột thật của bảng/seed `import_danhmuc_nhomdichvu_sci` ngoài 3 cột
  được dùng (`code`/`name`/`"brand_id/name"`) — chưa rõ, cần đối chiếu với
  file Excel/CSV export thật trước khi nạp seed.
- Chưa kiểm tra dữ liệu ERP thật (`sh_medical_health_center_service_category`,
  `product_category`, `res_brand`, `ir_model_data`) — không tự ý connect/query
  DB khi chưa được yêu cầu, theo nguyên tắc làm việc chung.

## File import bảng giá (theo model import_banggia_sci) cho lô "Cấy tóc TNK"

Nguồn: sheet "2025_NY" trong `1. TEMPLATE BẢNG GIÁ DV CẤY TÓC UPDATE HỆ THỐNG
_ ĐỐI TÁC TNK (1).xlsx` (4 dòng, cùng 4 dịch vụ HT-1/HT-2/BT-1/ET-1 đã import
ở bước dịch vụ). Cột `product_id/id` (chứa mã thô) và `product_id` (chứa tên
đầy đủ) trong file nguồn bị **đảo ngược** so với ý nghĩa seed
`import_bang_gia_chi_tiet_sci_seed` (`product_id` phải là mã thô để match
`default_code`) — đã sửa lại theo đúng nghĩa.

**Dữ liệu thật đối chiếu trực tiếp trên `kangnam_erp` (2026-09-03, anh tự
chạy SQL/export UI Odoo giúp em vì kết nối DB ngoài bị chặn ở tầng permission
tool)**, do 4 dịch vụ này **chưa đồng bộ sang `new_product`** (DB dbt target
`dev` đang trỏ tới) nên không tự query qua dbt được:

| default_code | product_product.id | product_ext_id (`product.product`) |
|---|---|---|
| HT-1 | 41453 | `__export__.product_product_41453_584d33aa` |
| HT-2 | 41454 | `__export__.product_product_41454_fd1a2194` |
| BT-1 | 41455 | `__export__.product_product_41455_ae45fad1` |
| ET-1 | 41456 | `__export__.product_product_41456_d9b0b612` |

(external id trên chỉ có sau khi anh **export 4 sản phẩm từ UI Odoo** kèm cột
External ID — trước đó `product.product` chưa có external id, chỉ riêng
`sh_medical_health_center_service` wrapper có.)

Pricelist "Bảng giá khách hàng Đối tác TNK 2026" đã tồn tại (không phải bảng
giá mới): `product_pricelist.id = 145`, external id
`__export__.product_pricelist_145_bc839560` (tra qua export UI, người tạo
"Nguyễn Hữu Linh"). **Giả định chưa xác minh trực tiếp**: `pricelist_active =
true` và `brand_etl = 1` (Kangnam) cho pricelist này — hợp lý vì mới tạo cho
đúng dự án Kangnam nhưng chưa có query xác nhận 2 giá trị này trực tiếp.

Không có `product_pricelist_item` nào khớp sẵn (4 dòng giá hoàn toàn mới cho
pricelist này) → `id_chi_tiet_bang_gia = null` cho cả 4 → theo đúng logic
`int_ibgs_p`, `id` mới được sinh dạng
`__import__.product_pricelist_item_145_<default_code>`.

**Kết quả tính tay (mô phỏng đúng chuỗi int_ibgs_a → extenal_data → d →
duplicate_products → k → pp → g → p → mart, không chạy dbt vì new_product
chưa có dữ liệu)**: cả 4 dòng `status_data = ' | product_id mới (chưa có
trong bảng giá)'` → `is_record_false = false` (hợp lệ, không phải lỗi).
Riêng `"Trạng thái"` vẫn ra `"Team QTDL kiểm tra lại"` cho cả 4 dòng — đây là
đặc điểm có sẵn của logic gốc `output_import_banggia.sql` (điều kiện
`pp.false_extenal_id = od.status_data` luôn đúng khi status chỉ đến từ `pp`,
không phải lỗi phát sinh khi chuyển đổi) — không phải dấu hiệu dữ liệu sai.

File kết quả: `Import_master_data/2026-09-03/Cấy tóc thổ nhĩ kỳ/5. Output
import_banggia_sci - Cấy tóc TNK 2026.xlsx` (20 cột, đúng schema
`output_import_banggia`, 4 dòng).
