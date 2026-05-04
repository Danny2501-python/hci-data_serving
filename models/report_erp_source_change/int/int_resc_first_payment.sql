with spt as (
    select * from {{ ref('stg_resc_payment_transfer') }}
),
ranked_payments as (
    select 
        crm_id, 
        brand_etl, 
        payment_date, 
        row_number() over (partition by crm_id, brand_etl order by payment_date) as rnk
    from spt
)
select * from ranked_payments where rnk = 1
