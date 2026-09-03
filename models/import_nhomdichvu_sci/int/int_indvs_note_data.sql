-- Tương ứng CTE `note_data` trong Readme.md.
with output_data as (
    select * from {{ ref('int_indvs_output_data') }}
),
product_category as (
    select * from {{ ref('stg_indvs_product_category') }}
)

select
    a.id,
    a."name",
    a.code,
    a."product_cat_id/id",
    a."product_cat_id/name",
    a."parent_id/id",
    a.property_cost_method,
    a."brand_id/id",
    a."brand_id/name",
    a.property_valuation,
    case
        when a.code is null then null
        when not exists (select 1 from product_category pc where pc.code = a.code) then true
        else false
    end as is_prod_cat_new
from
    output_data a
