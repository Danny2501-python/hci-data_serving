with cl as (
    select * from {{ ref('stg_resc_crm_lead') }}
)
select distinct cl.id, cl.brand_etl
from cl
inner join cl cl2 on cl2.lead_id = cl.id and cl2.brand_etl = cl.brand_etl
where cl."type" = 'lead'
