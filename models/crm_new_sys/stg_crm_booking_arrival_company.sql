{{ config(materialized='table') }}

with cls as (
    select 
        cl.id as crm_id, 
        cl.contact_name, 
        cl.name as booking, 
        cl.arrival_date, 
        cl.company_id, 
        ccsr.company as share_company_id, 
        cl.brand_etl 
    from {{ source('erp', 'crm_lead') }} cl
    left join {{ source('erp', 'company_crm_share_ref') }} ccsr on cl.id = ccsr.crm and ccsr.brand_etl = cl.brand_etl 
    where cl.brand_etl > 0 
    and cl.type_crm_id = 2 
    and cl.company_id <> ccsr.company 
    and cl.customer_come = 'yes'
),

cline as (
    select 
        cls.*, 
        l.id as clineid, 
        l.product_id, 
        l.consultants_1 as consultants, 
        se.employee, 
        se.job, 
        se.company_id as employee_company_id,
        case 
            when se.company_id = cls.company_id or se.company_id = cls.share_company_id 
            then true else false 
        end as is_branch_consult, 
        case when l.stage in ('cancel') then 0 else 1 end as is_done
    from {{ source('erp', 'crm_line') }} l 
    right join cls on l.crm_id = cls.crm_id and l.brand_etl = cls.brand_etl
    left join {{ ref('stg_employees') }} se on l.consultants_1 = 
        (case 
            when l.brand_etl = 1 then se.id -- kn_user_id logic tương đương
            when l.brand_etl = 3 then se.id 
            when l.brand_etl = 4 then se.id 
            else se.user_id 
        end)
),

ranked as (
    select 
        *,
        case when employee_company_id = share_company_id then share_company_id else company_id end as arrival_company_id, 
        row_number() over (
            partition by brand_etl, crm_id 
            order by is_done desc, is_branch_consult desc, clineid
        ) as rn
    from cline
)

select 
    crm_id, contact_name, booking, arrival_date, company_id, share_company_id, brand_etl,
    arrival_company_id
from ranked
where rn = 1
