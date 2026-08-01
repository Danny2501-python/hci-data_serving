-- Nguồn nhập liệu: seed import_bang_gia_chi_tiet_sci_seed (business user export Excel -> CSV UTF-8,
-- ghi đè seeds/import_bang_gia_chi_tiet_sci_seed.csv, chạy `dbt seed --select import_bang_gia_chi_tiet_sci_seed`
-- trước khi `dbt run`) thay vì bảng ERP import_bang_gia_chi_tiet_sci trực tiếp -- xem LOGIC.md.
select
    stt,
    id,
    pricelist_id,
    "pricelist_id/id",
    "product_id/id",
    product_id,
    "fixed_price - giá gốc",
    "fixed_price - giá min",
    applied_on,
    "bảng giá trong khoảng",
    max_discount_mkt,
    max_discount_increase_local,
    discount_old_customer,
    deep_discount,
    ghi_chu,
    brand
from {{ ref('import_bang_gia_chi_tiet_sci_seed') }}
