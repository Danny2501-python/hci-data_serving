SELECT 
        id,
        arrival_date, 
        contact_name, 
        code_customer, 
        name, 
        phone, 
        type_crm_id ,
        create_by, 
        source_id, 
        brand_etl,
        partner_id
    FROM {{ source('raw_data', 'crm_lead') }} 
    WHERE type_crm_id <>3