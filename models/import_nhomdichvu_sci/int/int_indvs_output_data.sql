-- Tương ứng CTE `output_data` trong Readme.md.
with nhom_dichvu as (
    select * from {{ ref('int_indvs_nhom_dichvu') }}
),
product_category as (
    select * from {{ ref('stg_indvs_product_category') }}
)

select
    case
        when a.id is null and not exists (select 1 from product_category pc where pc.code = a.code) then concat('__import__.',a.code)
        else a.id
    end as id,
    a."name",
    a.code,
    a."product_cat_id/id",
    a."product_cat_id/name",
    a."parent_id/id",
    a.property_cost_method,
    a."brand_id/id",
    a."brand_id/name",
    a.property_valuation,
    a.is_prod_cat_duplicate
from nhom_dichvu a
