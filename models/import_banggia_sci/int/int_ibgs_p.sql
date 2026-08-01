with g as (select * from {{ ref('int_ibgs_g') }}),
a as (select * from {{ ref('int_ibgs_a') }})

select
    g.stt,
    case
        when g.id = '' and a.id_chi_tiet_bang_gia is null and a.id_bang_gia is not null
            and a.id_dv is not null and not exists
                (select 1 from (select * from {{ ref('int_ibgs_ir_model_data_data') }} c where c.model = 'product.pricelist.item') l where a.id_chi_tiet_bang_gia = l.res_id)
                then concat('__import__.product_pricelist_item_', a.id_bang_gia::text, '_', a.product_id)
        else g.id
    end id,
    g.pricelist_id,
    g.pricelist_active,
    g."pricelist_id/id",
    g."product_id/id",
    g.product_id,
    g."fixed_price - giá gốc",
    g."fixed_price - giá min",
    g.applied_on,
    g."bảng giá trong khoảng",
    g.max_discount_mkt,
    g.max_discount_increase_local,
    g.discount_old_customer,
    g.deep_discount,
    g.ghi_chu,
    g.brand,
    case
        when g.stt is null then 'Thiếu "stt"'
        when g.pricelist_active is false then dd.false_actice_pricelist
        else concat(ibg.false_pricelist_id, g.status_data, ibg.false_applied_on, ibg.false_fixed_price, dd.false_max_discount_mkt, dd.false_max_discount_increase_local, dd.false_discount_old_customer, dd.false_deep_discount)
    end status_data
from g
left join (
    select
        i.stt,
        i.product_id,
        i.pricelist_id,
        case
            when applied_on is null then ' | Cột "applied_on" đang bị thiếu'
            else ''
        end as false_applied_on,
        case
            when i.pricelist_id ilike '%(VND)' then ' | Cột pricelist_id đang sai tên(thừa VND)'
            else ''
        end as false_pricelist_id,
        case
            when i."fixed_price - giá gốc" is null and i.pricelist_id not ilike '%bảo hành%' then ' | Cột "fixed_price - giá gốc" đang bị thiếu'
            else ''
        end as false_fixed_price
    from {{ ref('stg_ibgs_import_bang_gia_chi_tiet_sci') }} i
) ibg on ibg.stt = g.stt
left join a on a.stt = g.stt
left join (
    select
        g.stt,
        case
            when pricelist_active is false then 'Bảng giá đã inactive'
            else ''
        end false_actice_pricelist,
        case
            when max_discount_mkt::int > 100 then ' | Nhập thiếu giá trị % vào "max_discount_mkt"'
            else ''
        end false_max_discount_mkt,
        case
            when max_discount_increase_local::int > 100 then ' | Nhập thiếu giá trị % vào "max_discount_increase_local"'
            else ''
        end false_max_discount_increase_local,
        case
            when discount_old_customer::int > 100 then ' | Nhập thiếu giá trị % vào "discount_old_customer"'
            else ''
        end false_discount_old_customer,
        case
            when deep_discount::int > 100 then ' | Nhập thiếu giá trị % vào "deep_discount"'
            else ''
        end false_deep_discount
    from g
) dd on dd.stt = g.stt
