select  id, 
        brand_etl,
        payment_date, 
        payment_type,
        communication, 
        name
    from {{ source('raw_data', 'account_payment') }} 
    where state = 'posted' and payment_date >= '20250801'
    