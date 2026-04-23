    SELECT crm_line_id, 
    account_payment_id, 
    prepayment_amount,
     company_id, 
     brand_etl
    FROM {{ source('raw_data', 'crm_account_payment_detail') }} 
    WHERE prepayment_amount <> 0
