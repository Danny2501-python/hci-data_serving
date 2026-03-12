{{ config(materialized='table') }}

with partner_phones as (
    select 
        id, name as customer, code_customer, overseas_vietnamese, 
        phone, mobile, create_date, create_uid, brand_etl,
        regexp_replace(coalesce(phone, mobile), '^(0+|\+*84)', '0') as phone_fix
    from {{ source('erp', 'res_partner') }}
    where code_customer is not null 
    and code_customer not similar to '(NCC|S|CHC)%'
    and name is not null
    and brand_etl not in (0, 7)
),

ranked as (
    select 
        *,
        count(*) over (partition by phone_fix) as count_occur_phone,
        row_number() over (partition by phone_fix order by create_date) as rn_occur_phone
    from partner_phones
    where phone_fix is not null
)

select * from ranked
