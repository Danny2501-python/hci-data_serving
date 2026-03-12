{{ config(materialized='table') }}

with line_consultants as (
    -- Lấy tư vấn 1, 2 từ crm_line
    select 
        brand_etl, crm_id, id as clineid, consultants_1 as consultants, consulting_role_1 as consulting_role, 'consult_1' as ordinal_consult, stage
    from {{ source('erp', 'crm_line') }} where consultants_1 is not null and brand_etl > 0
    union all
    select 
        brand_etl, crm_id, id as clineid, consultants_2 as consultants, consulting_role_2 as consulting_role, 'consult_2' as ordinal_consult, stage
    from {{ source('erp', 'crm_line') }} where consultants_2 is not null and brand_etl > 0
),

final_prioritized as (
    select 
        lc.*,
        se.job,
        se.department,
        case 
            when lc.consulting_role = 'recept' then 1
            when se.department ~* 'letan' or se.department_id in (2430,2557,2612) then 2
            when se.department ~* 'sale' then 99
            else 4
        end as priority_consult_crm
    from line_consultants lc
    left join {{ ref('stg_employees') }} se on lc.consultants = se.user_id -- logic đơn giản hóa
)

select * from final_prioritized
