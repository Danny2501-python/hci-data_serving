-- Pass camp_2.1 (camp_product_data_1): crm_line_product (sản phẩm) + coupon,
-- tính số tiền KM theo coupon để gom theo chiến dịch.

select
    clp.id as clineid,
    clp.booking_id as crm_id,
    cl.name as booking,
    cl.brand_id,
    cl.company_id as company_id_bk,
    spt.company_id,
    cl.code_customer,
    rp."name" as customer_name,
    clp.price_unit,
    0 as price_min,
    clp.product_uom_qty quantity,
    1 as uom_price,
    clp.create_date,
    clp.stage_line_product as stage,
    case
        when cl.brand_id = 3 then ss2.org_source
        else ss1."source"
    end as "source",
    case
        when cl.brand_id = 3 then ss2.category_source_code
        else ss1.category_source_code
    end as category_source_code,
    sp.product_category,
    sp.product,
    spt.payment_date,
    date(clp.date_confirm_so) as max_date,
    coalesce(clp.total_before_discount::numeric(100,0), 0::numeric(100,0)) as total_before_discount,
    cc.campaign as campaign_name,
    cc.name as name_km,
    cc.discount as discount,
    cc.type_discount,
    case
        when cc.type_discount = 'sale_to' then clp.price_unit*1*coalesce(clp.product_uom_qty,0) - cc.discount
        when cc.type_discount = 'percent' then cc.discount * clp.price_unit*1*coalesce(clp.product_uom_qty,0) / 100
        when cc.type_discount = 'cash' then cc.discount*1*coalesce(clp.product_uom_qty,0)
    end as amount_discount,
    cc.service_min,
    clp.brand_etl
from {{ source('sdr_base', 'crm_line_product') }} clp
join {{ ref('sdr_lead') }} ld on ld.id = clp.booking_id and ld.brand_etl = clp.brand_etl
left join {{ source('sdr_base', 'crm_lead') }} cl on cl.id = clp.booking_id and cl.brand_etl = clp.brand_etl
left join {{ source('sdr_base', 'res_partner') }} rp on rp.id = cl.partner_id and rp.brand_etl = cl.brand_etl
left join {{ ref('stag_products') }} sp on sp.product_id = clp.product_id
left join {{ ref('stag_payment_transfer') }} spt on clp.id = spt.clineid and spt.crm_id = clp.booking_id and spt.brand_etl = clp.brand_etl
left join {{ ref('sdr_coupon') }} cc on cc.crm_line_product = clp.id and cc.booking_id = cl.id and cc.brand_etl = clp.brand_etl
left join {{ source('sdr_base', 'stag_sources') }} ss1 on ss1.old_id = cl.source_id
left join {{ source('sdr_base', 'stag_sources') }} ss2 on ss2.old_id = ss1.id_pr
