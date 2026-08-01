select
    idds.stt,
    idds.id,
    idds.pricelist_id,
    idds."pricelist_id/id",
    case
        when idds."product_id/id" is not null then null
    end "product_id/id",
    case
        when idds.product_id is null then idds."product_id/id"
        else idds.product_id
    end as product_id,
    idds."fixed_price - giá gốc"::numeric,
    idds."fixed_price - giá min"::numeric,
    idds.applied_on,
    idds."bảng giá trong khoảng",
    idds.max_discount_mkt::numeric * 100 as max_discount_mkt,
    idds.max_discount_increase_local::numeric * 100 as max_discount_increase_local,
    idds.discount_old_customer::numeric * 100 as discount_old_customer,
    idds.deep_discount::numeric * 100 as deep_discount,
    idds.ghi_chu,
    idds.brand
from {{ ref('stg_ibgs_import_bang_gia_chi_tiet_sci') }} idds
