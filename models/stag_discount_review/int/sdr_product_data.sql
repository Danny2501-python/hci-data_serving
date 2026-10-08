-- Pass 2.2 (product_data): thông tin quanh crm_line_product (sản phẩm). Cùng bộ
-- cột ý nghĩa như sdr_service_data (thứ tự cột khác — union ở
-- stag/sdr_line_union liệt kê cột tường minh). rnk dùng để dedup (rnk = 1).

select
    clp.id as clineid,
    clp.booking_id as crm_id,
    cl.brand_id,
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
    case
        when cl.brand_id = 3 then ss2.category_source
        else ss1.category_source
    end as category_source,
    coalesce(clp.crm_discount_review) as discount_review_id,
    cdr.name as discount_special,
    cdr.deep_approve_user,
    cv.id as voucher_id,
    cv.name as voucher_name,
    cc."name" as coupon_name,
    cc.service_min,
    cc.discount as discount_coupon,
    case
        when cc.type_discount = 'sale_to' and cc.service_min is true then cc.discount
        when cc.type_discount = 'percent' and cc.service_min is true then clp.price_unit*coalesce(clp.product_uom_qty,0) - cc.discount * clp.price_unit*coalesce(clp.product_uom_qty,0) / 100
        when cc.type_discount = 'cash' and cc.service_min is true then clp.price_unit*coalesce(clp.product_uom_qty,0) - cc.discount
        else 0
    end as price_min_new,
    cc.type_discount,
    sp.smhcsid,
    sp.product_id,
    sp.product_ctg_id,
    sp.product_category,
    sp.product,
    case
        when spt.payment is null then 0::numeric(100,10)
        else spt.payment
    end as payment,
    spt.payment_date,
    spt.id,
    spt.ma_phieu,
    spt.payment_type,
    date(clp.date_confirm_so) as max_date,
    spt.company_id,
    coalesce(clp.discount_percent * clp.total_before_discount / 100, 0) as discount_percent,
    coalesce(clp.discount_cash, 0) as discount_cash,
    coalesce(clp.discount_other, 0) as other_discount,
    coalesce(clp.sale_to, 0) as sale_to,
    coalesce(clp.total_before_discount::numeric(100,0), 0::numeric(100,0)) as total_before_discount,
    coalesce(clp.total_before_discount - clp.total, 0) as total_discount,
    case
        when clp.total_before_discount = 0::numeric(100,10) then 0::numeric(100,10)
        else (clp.total_before_discount - clp.total) / clp.total_before_discount * 100::numeric(100,10)
    end as "%discount",
    coalesce(clp.total, 0) as total,
    case
        when clp.total_before_discount::numeric(100,0) = 0 then 0
        when clp.total_before_discount::numeric(100,0) <> 0 and coalesce(clp.sale_to, 0::numeric(100,10)) = 0 and coalesce(clp.discount_other, 0::numeric(100,10)) <> 0 then (coalesce(clp.discount_percent * clp.total_before_discount::numeric(100,10) / 100::numeric(100,10), 0::numeric(100,10)) + coalesce(clp.discount_cash, 0::numeric(100,10))::numeric(100,10) + coalesce(clp.discount_other, 0::numeric(100,10))::numeric(100,10))
        when clp.total_before_discount::numeric(100,0) <> 0 and coalesce(clp.sale_to, 0::numeric(100,10)) = 0 and coalesce(clp.discount_other, 0::numeric(100,10)) = 0 then (coalesce(clp.discount_percent * clp.total_before_discount::numeric(100,10) / 100::numeric(100,10), 0::numeric(100,10)) + coalesce(clp.discount_cash, 0::numeric(100,10))::numeric(100,10) + coalesce(clp.discount_other, 0::numeric(100,10))::numeric(100,10))
        else (clp.total_before_discount - coalesce(clp.sale_to, 0::numeric(100,10)) + coalesce(clp.discount_other, 0::numeric(100,10)))
    end as amout_test_discount,
    case
        when cdr.type_discount = 'discount_cash' then cdr.discount
        when cdr.type_discount = 'discount_pr' then cdr.discount/100*total_before_discount
        else 0
    end as amout_test_discount_cs,
    cc.campaign as campaign_coupon,
    cv.campaign as campaign_voucher,
    case
        when cc.type_discount = 'sale_to' then clp.price_unit*1*coalesce(clp.product_uom_qty,0) - cc.discount
        when cc.type_discount = 'percent' then cc.discount * clp.price_unit*1*coalesce(clp.product_uom_qty,0) / 100
        when cc.type_discount = 'cash' then cc.discount
    end as amount_discount_coupon,
    case
        when cv.type_discount = 'sale_to' then clp.price_unit*1*coalesce(clp.product_uom_qty,0) - cv.discount
        when cv.type_discount = 'percent' then cv.discount * clp.price_unit*1*coalesce(clp.product_uom_qty,0) / 100
        when cv.type_discount = 'cash' and cv.type_voucher <> 'discount_invoice' then cv.discount*1*coalesce(clp.product_uom_qty,0)
        when cv.type_discount = 'cash' and cv.type_voucher = 'discount_invoice' then cv.discount
    end as amount_discount_voucher,
    row_number() over (partition by clp.brand_etl, clp.id, clp.booking_id, spt.id, cv.id, cc.id order by cv.create_date) rnk,
    clp.brand_etl
from (
    select clp.*, sp.product_ctg_id as product_ctg_id_new
    from {{ source('sdr_base', 'crm_line_product') }} clp
    left join {{ ref('stag_products') }} sp on sp.product_id = clp.product_id
) clp
left join {{ source('sdr_base', 'crm_lead') }} cl on cl.id = clp.booking_id and cl.brand_etl = clp.brand_etl
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
left join {{ ref('sdr_coupon') }} cc on cc.crm_line_product = clp.id and cc.booking_id = cl.id and cc.brand_etl = clp.brand_etl
left join (
    select cdr.*, rp."name" as deep_approve_user
    from {{ source('sdr_base', 'crm_discount_review') }} cdr
    left join {{ source('sdr_base', 'res_users') }} ru on ru.id = cdr.user_approve and ru.brand_etl = cdr.brand_etl
    left join {{ source('sdr_base', 'res_partner') }} rp on rp.id = ru.partner_id and rp.brand_etl = ru.brand_etl
) cdr on cdr.id = clp.crm_discount_review and cdr.brand_etl = clp.brand_etl
left join {{ source('sdr_base', 'stag_sources') }} ss1 on ss1.old_id = cl.source_id
left join {{ source('sdr_base', 'stag_sources') }} ss2 on ss2.old_id = ss1.id_pr
