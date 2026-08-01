with input_data as (select * from {{ ref('int_ibgs_input_data') }}),
product_product as (select * from {{ ref('stg_ibgs_product_product') }}),
product_pricelist as (select * from {{ ref('stg_ibgs_product_pricelist') }}),
product_pricelist_item as (select * from {{ ref('stg_ibgs_product_pricelist_item') }})

select
    a.stt,
    a.id,
    a.pricelist_id,
    b.active as pricelist_active,
    a."pricelist_id/id",
    a."product_id/id",
    a.product_id,
    a."fixed_price - giá gốc",
    a."fixed_price - giá min",
    a.applied_on,
    case
        when a.max_discount_mkt is null then d.max_discount_mkt
        else a.max_discount_mkt
    end as max_discount_mkt,
    case
        when a.max_discount_increase_local is null then d.max_discount_increase_local
        else a.max_discount_increase_local
    end as max_discount_increase_local,
    case
        when a.discount_old_customer is null then d.discount_old_customer
        else a.discount_old_customer
    end as discount_old_customer,
    case
        when a.deep_discount is null then d.deep_discount
        else a.deep_discount
    end as deep_discount,
    a.ghi_chu,
    a.brand,
    b.id as id_bang_gia,
    b."name" as name_bang_gia,
    c.id as id_dv,
    d.id as id_chi_tiet_bang_gia
from input_data a
left join product_product c on
    lower(c.default_code) = lower(a.product_id) and a.brand = c.brand_etl
left join (select * from product_pricelist b where b.brand_id not in (2,5)) b on
    lower(b."name") = lower(a.pricelist_id) and a.brand = b.brand_etl
left join product_pricelist_item d on
    d.product_id = c.id
    and d.pricelist_id = b.id and a.brand = d.brand_etl
order by a.stt asc
