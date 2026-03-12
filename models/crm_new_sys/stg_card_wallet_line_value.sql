{{ config(materialized='table') }}

with card_base as (
    select 
        cwt.id, 
        pwt.id as pwt_id, 
        pcwtr.card_id, 
        pwt.wallet_id, 
        pw.partner_id, 
        cw.code as card_code, 
        pwt.line_id as clineid, 
        cline.product_id, 
        sp.product, 
        cline.total, 
        cline.quantity, 
        case when coalesce(cline.quantity, 0) = 0 then 0 else cline.total/cline.quantity end as unit_total, 
        coalesce(cwt.amount, pwt.amount) as pwt_amount, 
        case when pwt.type = 'ht' then -cwt.amount else cwt.amount end as amount, 
        pwt.type as pwt_type, 
        cwt.type as cwt_type,  
        spc.product as card_name, 
        cwv.value_face, 
        cwv.bonus, 
        cwv.value, 
        cwv.gift, 
        case when coalesce(cwv.value, 0) = 0 then 0 else cwv.value_face/cwv.value end as rto_value, 
        cw.amount_done, 
        cw.value_total, 
        pw.name as wallet_name, 
        pw.code_customer, 
        pwt.crm_id, 
        pwt.brand_etl, 
        pwt.create_date, 
        pwt.write_date 
    from {{ source('erp', 'partner_wallet_transaction') }} pwt 
    left join {{ source('erp', 'partner_wallet') }} pw on pwt.wallet_id = pw.id and pwt.brand_etl = pw.brand_etl 
    left join {{ source('erp', 'partner_card_wallet_transaction_rel') }} pcwtr on pcwtr.wallet_tran_id = pwt.id and pcwtr.brand_etl = pwt.brand_etl 
    left join {{ source('erp', 'card_wallet') }} cw on pcwtr.card_id = cw.id and pcwtr.brand_etl = cw.brand_etl 
    left join {{ source('erp', 'card_wallet_transaction') }} cwt on cw.id = cwt.card_id and cw.brand_etl = cwt.brand_etl and cwt.pwt_id = pwt.id
    left join {{ source('erp', 'card_wallet_value') }} cwv on cw.card_value_id = cwv.id and cw.brand_etl = cwv.brand_etl 
    left join {{ source('erp', 'crm_line') }} cline on pwt.line_id = cline.id and pwt.brand_etl = cline.brand_etl 
    left join {{ ref('stg_products') }} sp on cline.product_id = sp.product_id and cline.brand_etl = sp.brand_etl 
    left join {{ ref('stg_products') }} spc on cwv.product_id = spc.product_id and cwv.brand_etl = spc.brand_etl 
    where pwt.brand_etl <> 0
),

calculations as (
    select
        *,
        (amount * rto_value) as actual_value,
        row_number() over (partition by clineid, brand_etl order by id desc) as rn_cline_desc,
        sum(pwt_amount) over (partition by clineid, brand_etl order by id) as pwt_amount_cum,
        sum(amount * rto_value) over (partition by clineid, brand_etl order by id) as actual_value_cum,
        sum(amount) over (partition by clineid, brand_etl, card_id order by id) as amount_card_cum,
        row_number() over (partition by clineid, brand_etl, card_id order by id desc) as rn_cline_card_desc
    from card_base
),

final as (
    select
        *,
        max(pwt_amount_cum) over (partition by clineid, brand_etl) as pwt_amount_last,
        max(actual_value_cum) over (partition by clineid, brand_etl) as actual_value_last,
        sum(actual_value) over (partition by clineid, brand_etl, card_id order by id) as actual_value_card_cum,
        case 
            when max(pwt_amount_cum) over (partition by clineid, brand_etl) = 0 then 0 
            else amount_card_cum / max(pwt_amount_cum) over (partition by clineid, brand_etl) 
        end as rto_value_card
    from calculations
)

select 
    *,
    (rto_value * rto_value_card) as rto_std,
    cast(pwt_id || '-' || id || '-' || brand_etl as varchar) as id_etl
from final
