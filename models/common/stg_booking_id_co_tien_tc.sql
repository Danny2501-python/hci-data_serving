{{
  config(
    materialized = 'ephemeral'
  )
}}
select spt.crm_id,spt.brand_etl, SUM(spt.payment) as total_payment
from {{ source('source_common', 'stag_payment_transfer') }} spt
    left join {{ source('source_common', 'crm_lead') }} cl on cl.id = spt.crm_id and cl.brand_etl = spt.brand_etl
where cl.stage_id = 4
group by spt.crm_id,spt.brand_etl
having SUM(spt.payment) > 0