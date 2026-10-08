-- Pass 1.2 (cte_voucher): chương trình voucher + mức giảm theo sản phẩm/nhóm
-- (discount_product, discount_service) hoặc theo khoảng giá trị hoá đơn
-- (discount_invoice: [invoice_value_minimum, invoice_value_maximum)).
-- Join theo brand_etl giữa các bảng có brand_etl (stag_products không có -> chỉ product_id).

with a as (
    -- Lấy chi nhánh áp dụng trong voucher
    select cvp.id, cvp.brand_etl, string_agg(rc."name", '|') as company_name
    from {{ source('sdr_base', 'crm_voucher_program') }} cvp
    join {{ source('sdr_base', 'crm_voucher_program_res_company_rel') }} cvprcr
        on cvprcr.crm_voucher_program_id = cvp.id and cvprcr.brand_etl = cvp.brand_etl
    join {{ source('sdr_base', 'm_res_company') }} rc
        on rc.id = cvprcr.res_company_id and rc.brand_etl = cvprcr.brand_etl
    group by cvp.id, cvp.brand_etl
),
b as (
    -- Lấy nguồn áp dụng trong voucher
    select cvp.id, cvp.brand_etl, string_agg(us."name", '|') as source_name
    from {{ source('sdr_base', 'crm_voucher_program') }} cvp
    join {{ source('sdr_base', 'crm_voucher_program_utm_source_rel') }} cvpusr
        on cvpusr.crm_voucher_program_id = cvp.id and cvpusr.brand_etl = cvp.brand_etl
    join {{ source('sdr_base', 'utm_source') }} us
        on us.id = cvpusr.utm_source_id and us.brand_etl = cvpusr.brand_etl
    group by cvp.id, cvp.brand_etl
),
cvpl as (
    select
        cvpl.voucher_program,
        cvpl.brand_etl,
        cvpl.product_id,
        smhcsc.product_cat_id product_ctg_id,
        cvpl.type_discount,
        cvpl.discount,
        cvpl.create_date,
        row_number() over (partition by cvpl.brand_etl, cvpl.voucher_program, cvpl.product_id, smhcsc.product_cat_id order by cvpl.create_date) rnk
    from {{ source('sdr_base', 'crm_voucher_program_list') }} cvpl
    left join {{ source('sdr_base', 'sh_medical_health_center_service_category') }} as smhcsc
        on smhcsc.id = cvpl.product_ctg_id and smhcsc.brand_etl = cvpl.brand_etl
    left join {{ ref('stag_products') }} sp on sp.product_id = cvpl.product_id
)
select
    cvp.id,
    cvp."name",
    cvp.active,
    cvp.type_voucher,
    cvp.start_date,
    cvp.end_date,
    uc."name" as campaign,
    cvp.check_min,
    cvp.service_min,
    cvp.brand_id,
    a.company_name,
    b.source_name,
    case
        when type_voucher = 'discount_invoice' then cvpdi.discount
        else cvpl.discount
    end as discount,
    case
        when type_voucher = 'discount_invoice' and cvp.type_discount_invoice = '1' then 'cash'
        when type_voucher = 'discount_invoice' and cvp.type_discount_invoice = '2' then 'percent'
        else cvpl.type_discount
    end as type_discount,
    cvpl.product_id,
    cvpl.product_ctg_id,
    cvpdi.invoice_value_minimum,
    coalesce(lead(cvpdi.invoice_value_minimum) over (partition by cvpdi.brand_etl, cvpdi.voucher_program order by cvpdi.invoice_value_minimum), 9999999999) invoice_value_maximum,
    cvpl.create_date,
    cvp.brand_etl
from {{ source('sdr_base', 'crm_voucher_program') }} cvp
left join {{ source('sdr_base', 'utm_campaign') }} uc
    on cvp.campaign_id = uc.id and uc.brand_etl = cvp.brand_etl
left join a on a.id = cvp.id and a.brand_etl = cvp.brand_etl
left join b on b.id = cvp.id and b.brand_etl = cvp.brand_etl
left join cvpl
    on cvpl.voucher_program = cvp.id and cvpl.brand_etl = cvp.brand_etl
    and type_voucher in ('discount_product', 'discount_service') and cvpl.rnk = 1
left join {{ source('sdr_base', 'crm_voucher_program_discount_invoice') }} cvpdi
    on cvpdi.voucher_program = cvp.id and cvpdi.brand_etl = cvp.brand_etl
    and type_voucher = 'discount_invoice'
