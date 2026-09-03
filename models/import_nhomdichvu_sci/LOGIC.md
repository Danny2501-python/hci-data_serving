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
