-- Pass camp_2.2 (camp_product_data_2): crm_line_product (sản phẩm) + voucher,
-- tính số tiền KM theo voucher để gom theo chiến dịch. rnk dùng để dedup (rnk = 1).

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
    cv.campaign as campaign_name,
    cv.name as name_km,
    cv.discount as discount,
    cv.type_discount,
    case
        when cv.type_discount = 'sale_to' then clp.price_unit*1*coalesce(clp.product_uom_qty,0) - cv.discount
        when cv.type_discount = 'percent' then cv.discount * clp.price_unit*1*coalesce(clp.product_uom_qty,0) / 100
        when cv.type_discount = 'cash' and cv.type_voucher <> 'discount_invoice' then cv.discount*1*coalesce(clp.product_uom_qty,0)
        when cv.type_discount = 'cash' and cv.type_voucher = 'discount_invoice' then cv.discount
    end as amount_discount,
    row_number() over (partition by clp.brand_etl, clp.id, clp.booking_id, spt.id, cv.id order by cv.create_date) rnk,
    clp.brand_etl
from (
    select clp.*, sp.product_ctg_id as product_ctg_id_new
    from {{ source('sdr_base', 'crm_line_product') }} clp
    left join {{ ref('stag_products') }} sp on sp.product_id = clp.product_id
) clp
join {{ ref('sdr_lead') }} ld on ld.id = clp.booking_id and ld.brand_etl = clp.brand_etl
left join {{ source('sdr_base', 'crm_lead') }} cl on cl.id = clp.booking_id and cl.brand_etl = clp.brand_etl
left join {{ source('sdr_base', 'res_partner') }} rp on rp.id = cl.partner_id and rp.brand_etl = cl.brand_etl
left join {{ ref('stag_products') }} sp on sp.product_id = clp.product_id
left join {{ ref('stag_payment_transfer') }} spt on clp.id = spt.clineid and spt.crm_id = clp.booking_id and spt.brand_etl = clp.brand_etl
left join {{ source('sdr_base', 'crm_line_product_crm_voucher_program_rel') }} clpcvpr on clp.id = clpcvpr.crm_line_product_id and clpcvpr.brand_etl = clp.brand_etl
left join {{ ref('sdr_voucher') }} cv on cv.id = clpcvpr.crm_voucher_program_id and cv.brand_etl = clpcvpr.brand_etl and (
    (
        (cv.product_id = clp.product_id or clp.product_ctg_id_new = cv.product_ctg_id)
        and cv.type_voucher <> 'discount_invoice'
    )
    or
    (
        cv.type_voucher = 'discount_invoice'
        and cv.invoice_value_minimum <= clp.total_before_discount and cv.invoice_value_maximum > clp.total_before_discount
    )
)
left join {{ source('sdr_base', 'stag_sources') }} ss1 on ss1.old_id = cl.source_id
left join {{ source('sdr_base', 'stag_sources') }} ss2 on ss2.old_id = ss1.id_pr
