select 
        payment_date,
        id id_phieu,
        ma_phieu,
        payment_method,
        quantity,
        payment,
        payment_type,
        company_id,
        crm_id,
        clineid,
        product_id
from {{source ('prs_raw_data', 'stag_payment_transfer')}}
where brand_etl =3