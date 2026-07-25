-- Tương đương phần 'cosmetic' của query_pm.
select
    concat('pc-', cappd.id) as id,
    'cosmetic' as product_type,
    ap.name as ma_phieu, ap.crm_id, ap.payment_date, ap.payment_method, ap.communication,
    clinep.id as clineid, clinep.product_id, clinep.product_uom_qty as quantity, 1 as uom_price,
    case when clinep.stage_line_product = 'sold' then clinep.product_uom_qty else 0 end as number_used,
    clinep.total,
    cappd.total_received, clinep.total_received as total_received_cline,
    case when ap.payment_type = 'outbound' then -cappd.prepayment_amount else cappd.prepayment_amount end as payment,
    ap.payment_type,
    clinep.stage_line_product as stage_product, clinep.consultants_1, clinep.consulting_role_1, clinep.consultants_2, clinep.consulting_role_2,
    cast(null as integer) as ho_tro,
    clinep.product_pricelist_id as price_list_id,
    ap.company_id as orgcompany_id,
    case
        when cappd.company_id is not null then cappd.company_id
        when ap.x_receive_company_id is null or ap.x_receive_company_id = 0 then ap.company_id
        else ap.x_receive_company_id
    end as company_id,
    ap.write_date + interval '7 hours' as write_date,
    ap.brand_id, ap.brand_etl
from {{ ref('stg_sptr_crm_account_payment_product_detail') }} cappd
left join {{ ref('stg_sptr_account_payment') }} ap on cappd.account_payment_id = ap.id and ap.brand_etl = cappd.brand_etl
left join {{ ref('stg_sptr_crm_line_product') }} clinep on cappd.crm_line_product_id = clinep.id and clinep.brand_etl = cappd.brand_etl
where cappd.brand_etl in (1, 3, 4)
    and ap.state = 'posted' and cappd.prepayment_amount <> 0
    and exists (
        select 1 from {{ ref('int_sptr_recent_crm_scope') }} s
        where s.crm_id = ap.crm_id and s.brand_etl = cappd.brand_etl
    )
