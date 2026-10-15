-- Pass 2.1 (service_data): thông tin quanh crm_line (dịch vụ) — nguồn, coupon,
-- voucher, duyệt KM đặc biệt, thanh toán, ngày làm dịch vụ (lần khám đầu).
-- rnk dùng để dedup ở stag/sdr_line_union (rnk = 1).

select
    cl2.id as clineid,
    cl2.crm_id,
    cl2.brand_id,
    cl2.unit_price,
    coalesce(cl2.price_min, 0) as price_min,
    cl2.quantity,
    cl2.uom_price,
    cl2.create_date,
    cl2.stage,
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
    coalesce(cl2.discount_review_id, 0) as discount_review_id,
    cdr.name as discount_special,
    cdr.deep_approve_user,
    cc.service_min,
    cc.discount as discount_coupon,
    case
        when cc.type_discount = 'sale_to' and cc.service_min is true then cc.discount
        when cc.type_discount = 'percent' and cc.service_min is true then cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) - cc.discount * cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) / 100
        when cc.type_discount = 'cash' and cc.service_min is true then cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) - cc.discount
        else coalesce(cl2.price_min, 0)*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0)
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
    pk.close_walkin max_date,
    spt.company_id,
    cv.id as voucher_id,
    cv.name as voucher_name,
    cc.id as coupon_id,
    cc.name as coupon_name,
    coalesce(cl2.discount_percent * cl2.total_before_discount / 100, 0) as discount_percent,
    coalesce(cl2.discount_cash, 0) as discount_cash,
    coalesce(cl2.other_discount, 0) as other_discount,
    coalesce(cl2.sale_to, 0) as sale_to,
    coalesce(cl2.discount_cs_percent, 0) as discount_cs_percent,
    coalesce(cl2.discount_cs_amount, 0) as discount_cs_amount,
    coalesce(cl2.total_discount_review, 0) as total_discount_review,
    coalesce(cl2.total_before_discount::numeric(100,0), 0::numeric(100,0)) as total_before_discount,
    coalesce(cl2.total_discount, 0::numeric(100,0)) as total_discount,
    case
        when cl2.total_before_discount = 0 then 0
        else cl2.total_discount / cl2.total_before_discount * 100
    end as "%discount",
    coalesce(cl2.total, 0) as total,
    case
        when cl2.total_before_discount::numeric(100,0) = 0 then 0
        when cl2.total_before_discount::numeric(100,0) <> 0 and coalesce(cl2.sale_to, 0::numeric(100,10)) = 0 and coalesce(cl2.other_discount, 0::numeric(100,10)) <> 0 then (coalesce(cl2.discount_percent * cl2.total_before_discount::numeric(100,10) / 100::numeric(100,10), 0::numeric(100,10)) + coalesce(cl2.discount_cash, 0::numeric(100,10))::numeric(100,10) + coalesce(cl2.other_discount, 0::numeric(100,10))::numeric(100,10))
        when cl2.total_before_discount::numeric(100,0) <> 0 and coalesce(cl2.sale_to, 0::numeric(100,10)) = 0 and coalesce(cl2.other_discount, 0::numeric(100,10)) = 0 then (coalesce(cl2.discount_percent * cl2.total_before_discount::numeric(100,10) / 100::numeric(100,10), 0::numeric(100,10)) + coalesce(cl2.discount_cash, 0::numeric(100,10))::numeric(100,10) + coalesce(cl2.other_discount, 0::numeric(100,10))::numeric(100,10))
        else (cl2.total_before_discount - coalesce(cl2.sale_to, 0::numeric(100,10)) + coalesce(cl2.other_discount, 0::numeric(100,10)))
    end as amout_test_discount,
    case
        when cl2.total_before_discount = 0::numeric(100,10) then 0
        else (coalesce(cl2.discount_cs_amount, 0::numeric(100,10)) + coalesce(cl2.total_discount_review, 0::numeric(100,10)))
    end as amout_test_discount_cs,
    cc.campaign as campaign_coupon,
    cv.campaign as campaign_voucher,
    case
        when cc.type_discount = 'sale_to' then cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) - cc.discount
        when cc.type_discount = 'percent' then cc.discount * cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) / 100
        when cc.type_discount = 'cash' then cc.discount
    end as amount_discount_coupon,
    case
        when cv.type_discount = 'sale_to' then cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) - cv.discount
        when cv.type_discount = 'percent' then cv.discount * cl2.unit_price*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0) / 100
        when cv.type_discount = 'cash' and cv.type_voucher <> 'discount_invoice' then cv.discount*coalesce(cl2.quantity,0)*coalesce(cl2.uom_price,0)
        when cv.type_discount = 'cash' and cv.type_voucher = 'discount_invoice' then cv.discount
    end as amount_discount_voucher,
    row_number() over (partition by cl2.brand_etl, cl2.id, cl2.crm_id, spt.id, cv.id, cc.id order by cv.create_date) rnk,
    cl2.brand_etl
from (
    select cl2.*, sp.product_ctg_id as product_ctg_id_new
    from {{ source('sdr_base', 'crm_line') }} cl2
    left join {{ ref('stag_products') }} sp on sp.product_id = cl2.product_id
) cl2
left join {{ source('sdr_base', 'crm_lead') }} cl on cl.id = cl2.crm_id and cl.brand_etl = cl2.brand_etl
left join {{ ref('sdr_coupon') }} cc on cc.crm_line = cl2.id and cc.booking_id = cl.id and cc.brand_etl = cl2.brand_etl
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
left join (
    select cdr.*, rp."name" as deep_approve_user
    from {{ source('sdr_base', 'crm_discount_review') }} cdr
    left join {{ source('sdr_base', 'res_users') }} ru on ru.id = cdr.user_approve and ru.brand_etl = cdr.brand_etl
    left join {{ source('sdr_base', 'res_partner') }} rp on rp.id = ru.partner_id and rp.brand_etl = ru.brand_etl
) cdr on cdr.id = cl2.discount_review_id and cdr.brand_etl = cl2.brand_etl
left join {{ ref('stag_products') }} sp on sp.product_id = cl2.product_id
left join {{ ref('stag_payment_transfer') }} spt on cl2.id = spt.clineid and spt.crm_id = cl2.crm_id and spt.brand_etl = cl2.brand_etl
left join {{ ref('sdr_walkin') }} pk
    on pk.brand_etl = cl2.brand_etl
    and pk.booking_id = cl2.crm_id
    and pk.product_id = cl2.product_id
    and pk.duration = 1
    and cl2.stage::text in ('done', 'processing', 'new')
    and pk.crm_line_id = cl2.id
