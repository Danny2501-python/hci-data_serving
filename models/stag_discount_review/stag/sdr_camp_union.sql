-- Pass camp_3 (union_data_2): gộp 4 nhánh KM theo chiến dịch
-- (dịch vụ/sản phẩm x coupon/voucher), chỉ dòng có name_km; nhánh voucher dedup rnk = 1.
-- brand_etl: cột kỹ thuật cho join / partition ở mart, không có trong output.

select
    'service' as table,
    'coupon'::text as type_data,
    dv1.clineid,
    dv1.crm_id,
    dv1.booking,
    dv1.code_customer,
    dv1.customer_name,
    dv1."source",
    dv1.category_source_code,
    case
        when dv1.company_id = dv1.company_id_bk or dv1.company_id <> dv1.company_id_bk then dv1.company_id
        else dv1.company_id_bk
    end cnpq,
    dv1.stage,
    dv1.total_before_discount,
    quantity,
    uom_price,
    dv1.product_category,
    dv1.product,
    case
        when dv1.payment_date is null and dv1.stage::text in ('done', 'processing', 'new') then dv1.max_date
        else dv1.payment_date
    end as dim_date,
    dv1.campaign_name,
    dv1.name_km,
    dv1.type_discount,
    dv1.discount,
    dv1.amount_discount,
    dv1.service_min,
    dv1.brand_etl
from {{ ref('sdr_camp_service_coupon') }} dv1
where name_km is not null
union all
(
    select
        'service' as table,
        'voucher'::text as type_data,
        dv2.clineid,
        dv2.crm_id,
        dv2.booking,
        dv2.code_customer,
        dv2.customer_name,
        dv2."source",
        dv2.category_source_code,
        case
            when dv2.company_id = dv2.company_id_bk or dv2.company_id <> dv2.company_id_bk then dv2.company_id
            else dv2.company_id_bk
        end cnpq,
        dv2.stage,
        dv2.total_before_discount,
        quantity,
        uom_price,
        dv2.product_category,
        dv2.product,
        case
            when dv2.payment_date is null and dv2.stage::text in ('done', 'processing', 'new') then dv2.max_date
            else dv2.payment_date
        end as dim_date,
        dv2.campaign_name,
        dv2.name_km,
        dv2.type_discount,
        dv2.discount,
        dv2.amount_discount,
        null::bool as service_min,
        dv2.brand_etl
    from {{ ref('sdr_camp_service_voucher') }} dv2
    where name_km is not null and rnk = 1
)
union all
(
    select
        'product' as table,
        'coupon'::text as type_data,
        sp1.clineid,
        sp1.crm_id,
        sp1.booking,
        sp1.code_customer,
        sp1.customer_name,
        sp1."source",
        sp1.category_source_code,
        case
            when sp1.company_id = sp1.company_id_bk or sp1.company_id <> sp1.company_id_bk then sp1.company_id
            else sp1.company_id_bk
        end cnpq,
        sp1.stage,
        sp1.total_before_discount,
        sp1.quantity,
        uom_price,
        sp1.product_category,
        sp1.product,
        case
            when sp1.payment_date is null and sp1.stage::text in ('sold', 'new') then sp1.max_date
            else sp1.payment_date
        end as dim_date,
        sp1.campaign_name,
        sp1.name_km,
        sp1.type_discount,
        sp1.discount,
        sp1.amount_discount,
        sp1.service_min,
        sp1.brand_etl
    from {{ ref('sdr_camp_product_coupon') }} sp1
    where name_km is not null
)
union all
(
    select
        'product' as table,
        'voucher'::text as type_data,
        sp2.clineid,
        sp2.crm_id,
        sp2.booking,
        sp2.code_customer,
        sp2.customer_name,
        sp2."source",
        sp2.category_source_code,
        case
            when sp2.company_id = sp2.company_id_bk or sp2.company_id <> sp2.company_id_bk then sp2.company_id
            else sp2.company_id_bk
        end cnpq,
        sp2.stage,
        sp2.total_before_discount,
        sp2.quantity,
        uom_price,
        sp2.product_category,
        sp2.product,
        case
            when sp2.payment_date is null and sp2.stage::text in ('sold', 'new') then sp2.max_date
            else sp2.payment_date
        end as dim_date,
        sp2.campaign_name,
        sp2.name_km,
        sp2.type_discount,
        sp2.discount,
        sp2.amount_discount,
        null::bool as service_min,
        sp2.brand_etl
    from {{ ref('sdr_camp_product_voucher') }} sp2
    where name_km is not null and rnk = 1
)
