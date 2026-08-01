with a as (select * from {{ ref('int_ibgs_a') }}),
ir_model_data_data as (select * from {{ ref('int_ibgs_ir_model_data_data') }})

select
    a.*,
    concat(c.module,'.',c.name) as extenal_id_chi_tiet_bang_gia,
    concat(d.module,'.',d.name) as extenal_id_bang_gia,
    concat(e.module,'.',e.name) as extenal_id_dichvu
from a
left join lateral (
    select
        c.res_id,
        c.name,
        c.module
    from ir_model_data_data c
    where
        c.model = 'product.pricelist.item'
        and c.res_id = a.id_chi_tiet_bang_gia and (c.brand_etl = a.brand or c.brand_etl = 0)
    order by c.date_update desc
    limit 1
) c on true
left join lateral (
    select
        c.res_id,
        c.name,
        c.module
    from ir_model_data_data c
    where
        c.model = 'product.pricelist'
        and c.res_id = a.id_bang_gia and (c.brand_etl = a.brand or c.brand_etl = 0)
    order by c.date_update desc
    limit 1
) d on true
left join lateral (
    select
        c.res_id,
        c.name,
        c.module
    from ir_model_data_data c
    where
        c.model = 'product.product'
        and c.res_id = a.id_dv and (c.brand_etl = a.brand or c.brand_etl = 0)
    order by c.date_update desc
    limit 1
) e on true
