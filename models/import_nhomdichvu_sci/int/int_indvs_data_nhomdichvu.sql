-- Tương ứng CTE `data_nhomdichvu` trong Readme.md (gồm 3 CTE lồng bên trong: a/b/c).
-- Giữ nguyên cấu trúc lồng gốc trong 1 model vì a/b/c chỉ được dùng nội bộ CTE này,
-- không được CTE nào khác trong query gốc ref trực tiếp - xem LOGIC.md.
with sh_medical_health_center_service_category as (
    select * from {{ ref('stg_indvs_sh_medical_health_center_service_category') }}
),
product_category as (
    select * from {{ ref('stg_indvs_product_category') }}
),
ir_model_data as (
    select * from {{ ref('stg_indvs_ir_model_data') }}
),
res_brand as (
    select * from {{ ref('stg_indvs_res_brand') }}
),

a as (
    select
        a.id,
        pc."name",
        pc.code,
        b.product_cat_id as "product_cat_id/id",
        pc."name" as "product_cat_id/name",
        'shealth_all_in_one.sh_services' as "parent_id/id",
        'standard' as property_cost_method,
        c.brand_id as "brand_id/id",
        c.brand_name as "brand_id/name",
        'manual_periodic' as property_valuation
    from
        (select * from sh_medical_health_center_service_category a where exists (select 1 from product_category pc where pc.id = a.product_cat_id)) smhcsc
    join product_category pc on
        pc.id = smhcsc.product_cat_id
    left join (
        select
            imd.res_id,
            concat(imd."module",'.',imd."name") as id
        from
            ir_model_data imd
        where
            model = 'sh.medical.health.center.service.category' and imd."module" not ilike '%export%') a on a.res_id = smhcsc.id
    left join (
        select
            imd.res_id,
            concat(imd."module",'.',imd."name") as product_cat_id
        from
            ir_model_data imd
        where
            model = 'product.category'
    ) b on b.res_id = pc.id
    left join (select
        rb.id,
        rb."name" as brand_name,
        concat(imd."module",'.',imd."name") as brand_id
    from
        res_brand rb
    join ir_model_data imd on
        rb.id = imd.res_id
    where
        imd.model = 'res.brand') c on c.id = pc.brand_id
),
b as (
    select a.code, count(*) as prod_cat_nam_ct
    from a group by a.code
),
c as (
    select a.*, b.prod_cat_nam_ct from a
    join b on a.code = b.code
    where a.id is not null
)
select a.*,
    case
        when c.prod_cat_nam_ct > 1 then true
        when c.prod_cat_nam_ct = 1 and a.code is not null and a.id is null and a."product_cat_id/id" is null then true
        else false
    end as is_prod_cat_duplicate
from a
join c on a.code = c.code
where a.id is not null
