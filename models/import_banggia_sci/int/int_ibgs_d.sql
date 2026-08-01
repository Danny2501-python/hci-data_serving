with extenal_data as (select * from {{ ref('int_ibgs_extenal_data') }})

select
    stt,
    trim(extenal_id_chi_tiet_bang_gia, '.') as id,
    pricelist_id,
    pricelist_active,
    trim(extenal_id_bang_gia, '.') as "pricelist_id/id",
    trim(extenal_id_dichvu, '.') as "product_id/id",
    product_id,
    coalesce("fixed_price - giá gốc",0)::text as "fixed_price - giá gốc",
    "fixed_price - giá min"::text,
    applied_on,
    case
        when "fixed_price - giá gốc" = '0' and "fixed_price - giá gốc" is null then 'FALSE'
        when coalesce("fixed_price - giá min",0) = coalesce("fixed_price - giá gốc",0) then 'FALSE'
        else 'TRUE'
    end as "bảng giá trong khoảng",
    max_discount_mkt::text,
    max_discount_increase_local::text,
    discount_old_customer::text,
    deep_discount::text,
    ghi_chu,
    brand
from extenal_data
order by stt asc
