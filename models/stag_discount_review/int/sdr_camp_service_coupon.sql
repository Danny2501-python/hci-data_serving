-- Pass camp_1.1 (camp_service_data_1): crm_line (dịch vụ) có coupon, tính số
-- tiền KM theo coupon để gom theo chiến dịch (campaign).

select
    cl2.id as clineid,
    cl2.crm_id,
    cl.name as booking,
    cl2.brand_id,
    cl.company_id as company_id_bk,
    spt.company_id,
    cl.code_customer,
    rp."name" as customer_name,
    cl2.unit_price,
    coalesce(cl2.price_min, 0) as price_min,
    cl2.quantity,
    cl2.uom_price,
    cl2.stage,
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
    pk.close_walkin max_date,
    coalesce(cl2.total_before_discount::numeric(100,0), 0::numeric(100,0)) as total_before_discount,
    cc.campaign as campaign_name,
    cc.name as name_km,
    cc.discount as discount,
    cc.type_discount,
    case
        when cc.type_discount = 'sale_to' then cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) - cc.discount
        when cc.type_discount = 'percent' then cc.discount * cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) / 100
        when cc.type_discount = 'cash' then cc.discount*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0)
    end as amount_discount,
    cc.service_min,
    cl2.brand_etl
from (
    select * from {{ source('sdr_base', 'crm_line') }} cl2
    where exists (
        select 1 from {{ ref('sdr_coupon') }} cc
        where cc.crm_line = cl2.id and cc.booking_id = cl2.crm_id and cc.brand_etl = cl2.brand_etl
    )
) cl2
join {{ ref('sdr_lead') }} ld on ld.id = cl2.crm_id and ld.brand_etl = cl2.brand_etl
left join {{ source('sdr_base', 'crm_lead') }} cl on cl.id = cl2.crm_id and cl.brand_etl = cl2.brand_etl
left join {{ source('sdr_base', 'res_partner') }} rp on rp.id = cl.partner_id and rp.brand_etl = cl.brand_etl
left join {{ ref('sdr_coupon') }} cc on cc.crm_line = cl2.id and cc.booking_id = cl2.crm_id and cc.brand_etl = cl2.brand_etl
left join {{ source('sdr_base', 'stag_sources') }} ss1 on ss1.old_id = cl.source_id
left join {{ source('sdr_base', 'stag_sources') }} ss2 on ss2.old_id = ss1.id_pr
left join {{ ref('stag_products') }} sp on sp.product_id = cl2.product_id
left join {{ ref('stag_payment_transfer') }} spt on cl2.id = spt.clineid and spt.crm_id = cl2.crm_id and spt.brand_etl = cl2.brand_etl
left join {{ ref('sdr_walkin') }} pk
    on pk.brand_etl = cl2.brand_etl
    and pk.booking_id = cl2.crm_id
    and pk.product_id = cl2.product_id
    and pk.duration = 1
    and cl2.stage::text in ('done', 'processing', 'new')
    and pk.crm_line_id = cl2.id
