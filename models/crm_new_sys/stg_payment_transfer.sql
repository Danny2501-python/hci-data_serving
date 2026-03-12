{{ config(materialized='table') }}

with raw_payments as (
    -- Thanh toán Dịch vụ
    select 
        concat('ps-', capd.id) as id, 'service' as product_type, ap.name as ma_phieu, ap.crm_id, ap.payment_date, ap.payment_method, ap.communication, 
        cline.id as clineid, cline.product_id, cline.quantity, cline.uom_price, cline.number_used,
        case when cline.gia_truoc_huy > 0 then cline.gia_truoc_huy else cline.total end as total,
        capd.total_received as total_received_capd, cline.total_received as total_received_cline, 
        case when ap.payment_type = 'outbound' then - capd.prepayment_amount else capd.prepayment_amount end as payment,
        ap.payment_type, cline.stage as stage_product, ap.company_id as orgcompany_id,
        (ap.write_date + interval '7 hours') as write_date, ap.brand_id, ap.brand_etl
    from {{ source('erp', 'crm_account_payment_detail') }} capd
    left join {{ source('erp', 'account_payment') }} ap on capd.account_payment_id = ap.id and ap.brand_etl = capd.brand_etl
    left join {{ source('erp', 'crm_line') }} cline on capd.crm_line_id = cline.id and cline.brand_etl = capd.brand_etl
    where ap.state = 'posted' and capd.prepayment_amount <> 0

    union all

    -- Thanh toán Sản phẩm
    select 
        concat('pc-', cappd.id) as id, 'cosmetic' as product_type, ap.name as ma_phieu, ap.crm_id, ap.payment_date, ap.payment_method, ap.communication, 
        clinep.id as clineid, clinep.product_id, clinep.product_uom_qty as quantity, 1 as uom_price,
        case when clinep.stage_line_product = 'sold' then clinep.product_uom_qty else 0 end as number_used,
        clinep.total, cappd.total_received as total_received_capd, clinep.total_received as total_received_cline, 
        case when ap.payment_type = 'outbound' then - cappd.prepayment_amount else cappd.prepayment_amount end as payment,
        ap.payment_type, clinep.stage_line_product as stage_product, ap.company_id as orgcompany_id,
        (ap.write_date + interval '7 hours') as write_date, ap.brand_id, ap.brand_etl
    from {{ source('erp', 'crm_account_payment_product_detail') }} cappd
    left join {{ source('erp', 'account_payment') }} ap on cappd.account_payment_id = ap.id and ap.brand_etl = cappd.brand_etl
    left join {{ source('erp', 'crm_line_product') }} clinep on cappd.crm_line_product_id = clinep.id and clinep.brand_etl = cappd.brand_etl
    where ap.state = 'posted' and cappd.prepayment_amount <> 0

    union all

    -- Điều chuyển - Outbound (From)
    select 
        concat('to-', ctpl.id) as id, 
        case when coalesce(ctpl.from_crm_line_id, 0) = 0 then 'cosmetic' else 'service' end as product_type,
        ctp.name as ma_phieu, ctp.crm_id, ctp.payment_date, 'pdc' as payment_method, ctp.communication,
        coalesce(nullif(ctpl.from_crm_line_id, 0), ctpl.from_crm_line_product_id) as clineid,
        coalesce(nullif(clinef.product_id, 0), clinepf.product_id) as product_id,
        coalesce(nullif(clinef.quantity, 0), clinepf.product_uom_qty) as quantity,
        clinef.uom_price,
        coalesce(nullif(clinef.number_used, 0), case when clinepf.stage_line_product = 'sold' then clinepf.product_uom_qty else 0 end) as number_used,
        case when clinef.gia_truoc_huy > 0 then clinef.gia_truoc_huy else coalesce(clinef.total, clinepf.total) end as total,
        ctpl.total_received as total_received_capd, clinef.total_received as total_received_cline,
        -ctpl.transfer_amount as payment, 'outbound' as payment_type, clinef.stage as stage_product,
        ctp.company_id as orgcompany_id, (ctp.write_date + interval '7 hours') as write_date, ctp.brand_id, ctp.brand_etl
    from {{ source('erp', 'crm_transfer_payment_line') }} ctpl
    left join {{ source('erp', 'crm_transfer_payment') }} ctp on ctpl.crm_transfer_payment_id = ctp.id and ctp.brand_etl = ctpl.brand_etl
    left join {{ source('erp', 'crm_line') }} clinef on ctpl.from_crm_line_id = clinef.id and clinef.brand_etl = ctpl.brand_etl
    left join {{ source('erp', 'crm_line_product') }} clinepf on ctpl.from_crm_line_product_id = clinepf.id and clinepf.brand_etl = ctpl.brand_etl
    where ctp.state = 'done' and ctpl.transfer_amount <> 0

    union all

    -- Điều chuyển - Inbound (To)
    select 
        concat('ti-', ctpl.id) as id, 
        case when coalesce(ctpl.to_crm_line_id, 0) = 0 then 'cosmetic' else 'service' end as product_type,
        ctp.name as ma_phieu, ctp.crm_id, ctp.payment_date, 'pdc' as payment_method, ctp.communication,
        coalesce(nullif(ctpl.to_crm_line_id, 0), ctpl.to_crm_line_product_id) as clineid,
        coalesce(nullif(clinet.product_id, 0), clinept.product_id) as product_id,
        coalesce(nullif(clinet.quantity, 0), clinept.product_uom_qty) as quantity,
        clinet.uom_price,
        coalesce(nullif(clinet.number_used, 0), case when clinept.stage_line_product = 'sold' then clinept.product_uom_qty else 0 end) as number_used,
        case when clinet.gia_truoc_huy > 0 then clinet.gia_truoc_huy else coalesce(clinet.total, clinept.total) end as total,
        null as total_received_capd, clinet.total_received as total_received_cline, -- logic ctplt bỏ qua đơn giản
        ctpl.transfer_amount as payment, 'inbound' as payment_type, clinet.stage as stage_product,
        ctp.company_id as orgcompany_id, (ctp.write_date + interval '7 hours') as write_date, ctp.brand_id, ctp.brand_etl
    from {{ source('erp', 'crm_transfer_payment_line') }} ctpl
    left join {{ source('erp', 'crm_transfer_payment') }} ctp on ctpl.crm_transfer_payment_id = ctp.id and ctp.brand_etl = ctpl.brand_etl
    left join {{ source('erp', 'crm_line') }} clinet on ctpl.to_crm_line_id = clinet.id and clinet.brand_etl = ctpl.brand_etl
    left join {{ source('erp', 'crm_line_product') }} clinept on ctpl.to_crm_line_product_id = clinept.id and clinept.brand_etl = ctpl.brand_etl
    where ctp.state = 'done' and ctpl.transfer_amount <> 0
),

joined_info as (
    select 
        rp.*,
        co.total_received_old,
        co.first_date_payment as first_date_old,
        case when ma_phieu like 'PDC%' and total_received_cline > 0 then 1 else 0 end as is_priority
    from raw_payments rp
    left join {{ ref('stg_crm_line_info') }} co on rp.clineid = co.clineid and rp.brand_etl = co.brand_etl
),

final_calc as (
    select
        *,
        sum(payment) over (
            partition by crm_id, clineid, product_id 
            order by payment_date, is_priority desc, write_date
        ) + coalesce(total_received_old, 0) as total_received_cumsum_raw
    from joined_info
)

select 
    *,
    case 
        when round(total_received_cumsum_raw::numeric, 0) = round((total + coalesce(total_received_old, 0))::numeric, 0) then total
        else total_received_cumsum_raw
    end as total_received_cumsum
from final_calc
