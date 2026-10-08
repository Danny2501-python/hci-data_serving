-- Pass 3 (temp_view_stag_discount): union dịch vụ + sản phẩm (rnk = 1), đảo dấu
-- total_before_discount với phiếu outbound, chốt dim_date (ngày thanh toán, hoặc
-- ngày làm DV / xác nhận SO nếu chưa có phiếu).
-- brand_etl: cột kỹ thuật để join / partition ở các bước sau, KHÔNG có trong
-- output (mart liệt kê cột tường minh, giữ đúng thứ tự cột của function gốc).

select
    'service_data'::text as type_data,
    dv.clineid,
    dv.crm_id,
    dv."source",
    dv.category_source_code,
    dv.category_source,
    dv.stage,
    case
        when dv.payment_type::text = 'inbound'::text then dv.total_before_discount
        when dv.payment_type::text = 'outbound'::text then - dv.total_before_discount
        else dv.total_before_discount
    end as total_before_discount,
    dv.total_discount::numeric(100,0) as total_discount,
    dv."%discount",
    quantity,
    uom_price,
    price_min_new,
    amout_test_discount,
    amout_test_discount_cs,
    dv.total,
    dv.discount_percent,
    round(dv.discount_cash) as discount_cash,
    dv.other_discount,
    dv.sale_to,
    dv.discount_cs_percent,
    dv.discount_cs_amount,
    dv.total_discount_review,
    dv.price_min,
    dv.discount_review_id,
    dv.discount_special,
    dv.deep_approve_user,
    dv.payment_date,
    dv.id,
    dv.ma_phieu,
    dv.payment_type,
    dv.smhcsid,
    dv.product_id,
    dv.product_ctg_id,
    dv.product_category,
    dv.product,
    dv.max_date,
    dv.payment,
    case
        when dv.payment_date is null and dv.stage::text in ('done', 'processing', 'new') and dv.ma_phieu is null then dv.max_date
        else dv.payment_date
    end as dim_date,
    dv.company_id,
    dv.coupon_name,
    dv.voucher_name,
    dv.type_discount,
    dv.discount_coupon,
    dv.service_min,
    dv.campaign_coupon,
    dv.campaign_voucher,
    amount_discount_coupon,
    amount_discount_voucher,
    dv.brand_etl
from {{ ref('sdr_service_data') }} dv
where rnk = 1
union all
select
    'product_data'::text as type_data,
    sp.clineid,
    sp.crm_id,
    sp."source",
    sp.category_source_code,
    sp.category_source,
    sp.stage,
    case
        when sp.payment_type::text = 'inbound'::text then sp.total_before_discount
        when sp.payment_type::text = 'outbound'::text then - sp.total_before_discount
        else sp.total_before_discount
    end as total_before_discount,
    sp.total_discount::numeric(100,0) as total_discount,
    sp."%discount",
    sp.quantity,
    uom_price,
    price_min_new,
    amout_test_discount,
    amout_test_discount_cs,
    sp.total,
    sp.discount_percent,
    round(sp.discount_cash) as discount_cash,
    sp.other_discount,
    0 as sale_to,
    0 as discount_cs_percent,
    0 as discount_cs_amount,
    0 as total_discount_review,
    sp.price_min,
    sp.discount_review_id,
    sp.discount_special,
    sp.deep_approve_user,
    sp.payment_date,
    sp.id,
    sp.ma_phieu,
    sp.payment_type,
    sp.smhcsid,
    sp.product_id,
    sp.product_ctg_id,
    sp.product_category,
    sp.product,
    sp.max_date,
    sp.payment,
    case
        when sp.payment_date is null and sp.stage::text in ('sold', 'new') and sp.ma_phieu is null then sp.max_date
        else sp.payment_date
    end as dim_date,
    sp.company_id,
    sp.coupon_name,
    sp.voucher_name,
    sp.type_discount,
    sp.discount_coupon,
    sp.service_min,
    sp.campaign_coupon,
    sp.campaign_voucher,
    amount_discount_coupon,
    amount_discount_voucher,
    sp.brand_etl
from {{ ref('sdr_product_data') }} sp
where rnk = 1
