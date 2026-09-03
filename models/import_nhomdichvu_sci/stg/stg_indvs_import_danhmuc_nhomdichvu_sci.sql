-- Nguồn nhập liệu: seed import_danhmuc_nhomdichvu_sci_seed (business user export Excel -> CSV UTF-8,
-- ghi đè seeds/import_danhmuc_nhomdichvu_sci_seed.csv, chạy `dbt seed --select import_danhmuc_nhomdichvu_sci_seed`
-- trước khi `dbt run`) thay vì bảng ERP import_danhmuc_nhomdichvu_sci -- xem LOGIC.md mục "Nhập liệu qua seed".
-- Chỉ 3 cột code/name/"brand_id/name" được câu query gốc (Readme.md) dùng tới.
select
    code,
    "name",
    "brand_id/name"
from {{ ref('import_danhmuc_nhomdichvu_sci_seed') }}
