select 
        date(cl.arrival_date + interval '7 hour') arrival_date,
        date( cl.booking_date  + interval '7 hour') booking_date,
		date( cl.day_expire  + interval '7 hour') expire_date,
        cl.brand_id thuonghieu,
        cl.company_id lead_company,
        cl.id crm_id,
        cl.create_by_department,
        cl.customer_come,
        cl.name booking,
        cl.code_customer,
        cl.amount_paid,
        cl.type_crm_id,
        cl.type_data_partner,
        cl.contact_name,
        cl.source_id,
        cl.reason_out_sold,
        cl.reason_cancel_booking, 
        cl.stage_id
from  {{ source('prs_raw_data', 'crm_lead') }} cl
where brand_etl =3 and active is true
