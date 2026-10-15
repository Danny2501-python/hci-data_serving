-- Pass 1.1 (cte_coupon): coupon áp dụng trên từng crm_line / crm_line_product,
-- lấy bản ghi mới nhất theo (booking_id, crm_line) trong crm_line_discount_history.
-- new_product gộp nhiều ERP (brand_etl), id chỉ duy nhất trong 1 brand_etl ->
-- mọi join giữa các bảng có brand_etl đều thêm điều kiện brand_etl.

with a as (
    -- Lấy chi nhánh áp dụng trong coupon
    select cdp.id, cdp.brand_etl, string_agg(rc."name", ' | ') as company_name
    from {{ source('sdr_base', 'crm_discount_program') }} cdp
    join {{ source('sdr_base', 'crm_discount_program_res_company_rel') }} cdprcr
        on cdprcr.crm_discount_program_id = cdp.id and cdprcr.brand_etl = cdp.brand_etl
    join {{ source('sdr_base', 'm_res_company') }} rc
        on rc.id = cdprcr.res_company_id and rc.brand_etl = cdprcr.brand_etl
    group by cdp.id, cdp.brand_etl
),
b as (
    -- Lấy nguồn áp dụng trong coupon
    select cdp.id, cdp.brand_etl, string_agg(us."name", ' | ') as source_name
    from {{ source('sdr_base', 'crm_discount_program') }} cdp
    join {{ source('sdr_base', 'crm_discount_program_utm_source_rel') }} cdprcr
        on cdprcr.crm_discount_program_id = cdp.id and cdprcr.brand_etl = cdp.brand_etl
    join {{ source('sdr_base', 'utm_source') }} us
        on us.id = cdprcr.utm_source_id and us.brand_etl = cdprcr.brand_etl
    group by cdp.id, cdp.brand_etl
),
cte_crm_discount_program_list as (
    select cdpl.*, pp.id as product_id
    from {{ source('sdr_base', 'crm_discount_program_list') }} cdpl
    left join {{ source('sdr_base', 'product_ids') }} pi2
        on pi2.product_id = cdpl.id and pi2.brand_etl = cdpl.brand_etl
    left join {{ source('sdr_base', 'product_product') }} pp
        on pp.id = pi2.product_product_id and pp.brand_etl = pi2.brand_etl
),
c as (
    select
        cdp.id,
        cdp."name",
        cdp.active,
        cdp.coupon_type,
        cdp.start_date,
        cdp.end_date,
        uc."name" as campaign,
        cdp.check_min,
        cdp.service_min,
        cdp.brand_id,
        a.company_name,
        b.source_name,
        cldh."index",
        cldh.discount,
        cldh.type_discount,
        cldh.booking_id,
        cldh.crm_line,
        cldh.crm_line_product,
        cdpl.dc_min_qty,
        cdpl.dc_max_qty,
        cl.quantity,
        cldh.brand_etl,
        row_number() over (partition by cldh.brand_etl, booking_id, crm_line order by cldh.create_date desc) rnk
    from {{ source('sdr_base', 'crm_line_discount_history') }} cldh
    left join {{ source('sdr_base', 'crm_line') }} cl
        on cl.id = cldh.crm_line and cl.brand_etl = cldh.brand_etl
    left join {{ source('sdr_base', 'crm_discount_program') }} cdp
        on cldh.discount_program = cdp.id and cdp.brand_etl = cldh.brand_etl
    left join {{ source('sdr_base', 'utm_campaign') }} uc
        on cdp.campaign_id = uc.id and uc.brand_etl = cdp.brand_etl
    left join a on a.id = cdp.id and a.brand_etl = cdp.brand_etl
    left join b on b.id = cdp.id and b.brand_etl = cdp.brand_etl
    left join cte_crm_discount_program_list cdpl
        on cdpl.discount_program = cldh.discount_program
        and cl.product_id = cdpl.product_id
        and cldh."index" = cdpl."index"
        and cdpl.brand_etl = cldh.brand_etl
)
select * from c where rnk = 1
