select 
       name,
        (date + '7:00:00'::interval) date,
        (service_date_start + '7:00:00'::interval) service_date_start  ,
        state,
        brand_etl,
        booking_id,
        id, 
        sale_order_id
from {{ source('raw_data', 'sh_medical_appointment_register_walkin') }} 

