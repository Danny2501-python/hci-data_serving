{{ config(alias='output_import_nhomdichvu_dbt') }}

-- Tương ứng CTE `output_nhomdichvu` + select cuối trong Readme.md. Alias
-- 'output_import_nhomdichvu_dbt' để không ghi đè bảng đích thật (chưa xác nhận tên
-- bảng thật/có function plpgsql gốc nào ghi vào bảng đó hay không) - xem LOGIC.md
-- mục "Chưa xác nhận" trước khi cutover.
with type_data_nhomdichvu as (
    select * from {{ ref('int_indvs_type_data_nhomdichvu') }}
)

select tdn.id,
    tdn."name",
    tdn.code,
    tdn."product_cat_id/id",
    tdn."product_cat_id/name",
    tdn."parent_id/id",
    tdn.property_cost_method,
    tdn."brand_id/id",
    tdn."brand_id/name",
    tdn.property_valuation,
    tdn.data_status,
    case
        when tdn.data_status in ('Nhóm dịch vụ cũ', 'Nhóm dịch vụ mới') then false
        when tdn.is_prod_cat_duplicate is true then false
        else true
    end as is_record_false
from type_data_nhomdichvu tdn
