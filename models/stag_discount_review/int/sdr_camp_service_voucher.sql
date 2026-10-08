-- Pass camp_1.2 (camp_service_data_2): crm_line (dịch vụ) có voucher, tính số
-- tiền KM theo voucher để gom theo chiến dịch. rnk dùng để dedup (rnk = 1).

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
    cv.campaign as campaign_name,
    cv.name as name_km,
    cv.discount as discount,
    cv.type_discount,
    case
        when cv.type_discount = 'cash' and cv.type_voucher = 'discount_invoice' and cl2.other_discount <> 0 then cl2.other_discount
        when cv.type_discount = 'cash' and cv.type_voucher = 'discount_invoice' and cl2.other_discount = 0 then cl2.discount_cash
        when cv.type_discount = 'percent' and cv.type_voucher = 'discount_invoice' then cl2.other_discount
        when cv.type_discount = 'sale_to' then cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) - cv.discount
        when cv.type_discount = 'percent' and cv.type_voucher <> 'discount_invoice' then cv.discount * cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) / 100
        when cv.type_discount = 'cash' and cv.type_voucher <> 'discount_invoice' then cv.discount*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0)
    end as amount_discount,
    row_number() over (partition by cl2.brand_etl, cl2.id, cl2.crm_id, spt.id, cv.id order by cv.create_date) rnk,
    cl2.brand_etl
from (
    select cl2.*, sp.product_ctg_id as product_ctg_id_new
    from {{ source('sdr_base', 'crm_line') }} cl2
    left join {{ ref('stag_products') }} sp on sp.product_id = cl2.product_id
) cl2
join {{ ref('sdr_lead') }} ld on ld.id = cl2.crm_id and ld.brand_etl = cl2.brand_etl
left join {{ source('sdr_base', 'crm_lead') }} cl on cl.id = cl2.crm_id and cl.brand_etl = cl2.brand_etl
left join {{ source('sdr_base', 'res_partner') }} rp on rp.id = cl.partner_id and rp.brand_etl = cl.brand_etl
left join {{ source('sdr_base', 'line_voucher_ref') }} lvr on cl2.id = lvr.voucher and lvr.brand_etl = cl2.brand_etl
left join {{ ref('sdr_voucher') }} cv on cv.id = lvr.line and cv.brand_etl = lvr.brand_etl and (
    (
        (cv.product_id = cl2.product_id or cl2.product_ctg_id_new = cv.product_ctg_id)
        and cv.type_voucher <> 'discount_invoice'
    )
    or
    (
        cv.type_voucher = 'discount_invoice'
        and cv.invoice_value_minimum <= cl2.total_before_discount and cv.invoice_value_maximum > cl2.total_before_discount
    )
)
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
