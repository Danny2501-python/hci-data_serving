-- Tương ứng CTE `nhom_dichvu` trong Readme.md.
with import_danhmuc_nhomdichvu_sci as (
    select * from {{ ref('stg_indvs_import_danhmuc_nhomdichvu_sci') }}
),
data_nhomdichvu as (
    select * from {{ ref('int_indvs_data_nhomdichvu') }}
),
res_brand as (
    select * from {{ ref('stg_indvs_res_brand') }}
),
ir_model_data as (
    select * from {{ ref('stg_indvs_ir_model_data') }}
)

select
    case
        when a.code is null then null
        else a.id
    end as id,
    case
        when idns."name" is null then a."name"
        else idns."name"
    end as "name",
    idns.code,
    case
        when a.code is null then null
        else a."product_cat_id/id"
    end as "product_cat_id/id",
    case
        when idns."name" is null then a."name"
        else idns."name"
    end as "product_cat_id/name",
    'shealth_all_in_one.sh_services' as "parent_id/id",
    'standard' as property_cost_method,
    c.brand_id as "brand_id/id",
    idns."brand_id/name",
    'manual_periodic' as property_valuation,
    a.is_prod_cat_duplicate
from
    import_danhmuc_nhomdichvu_sci idns
left join data_nhomdichvu a on a.code = idns.code
left join (select
    rb."name" as brand_name,
    concat(imd."module",'.',imd."name") as brand_id
from
    res_brand rb
join ir_model_data imd on
    rb.id = imd.res_id
where
    imd.model = 'res.brand') c on c.brand_name = idns."brand_id/name"
