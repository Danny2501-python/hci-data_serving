{% set start_date = var('start_date', '2025-08-01') %}

SELECT 
    cl.id AS lead_id,
    cl.brand_etl,
    cl.phone,
    cl.name AS lead_name,
    cl.create_date,
    cl.booking_date,
    cl.arrival_date,
    cl.ticket_id,
    cl.contact_name,
    cl.type AS lead_type,
    cl.stage_id,
    cl.brand_id,
    cl.create_uid,
    cc.nhanvien_seeding,
    rb.name AS brand_name,
    res_c.name AS company_name,
    rb.id AS rb_id,
    sp.product,
    sp.product_category,
    sf.page_name, 
    sf.page_link,
    sf.doctor,
    employee.employee,
    employee.department,
    CASE 
        WHEN cl.brand_id = 3 THEN ss1.org_source
        ELSE ss.source
    END AS source_name
FROM {{ source('frots', 'crm_lead') }} cl
LEFT JOIN {{ source('frots', 'crm_line') }} cl2 ON cl2.crm_id = cl.id AND cl2.brand_etl = cl.brand_etl
LEFT JOIN {{ source('frots', 'view_stag_products') }} sp ON cl2.product_id = sp.product_id AND cl2.brand_etl = sp.brand_etl
LEFT JOIN {{ source('frots', 'm_res_company') }} res_c ON res_c.id = cl.company_id AND res_c.brand_etl = cl.brand_etl
LEFT JOIN {{ source('frots', 'res_brand') }} rb ON rb.id = res_c.brand_id AND rb.brand_etl = res_c.brand_etl
LEFT JOIN {{ ref('stg_frots_caresoft_tickets') }} cc ON cc.ticket_id::TEXT = cl.ticket_id::TEXT
LEFT JOIN {{ ref('stg_frots_seeding_form') }} sf ON sf.ticket_id::TEXT = cl.ticket_id::TEXT
LEFT JOIN {{ source('frots', 'stag_sources') }} ss ON ss.old_id = cl.source_id
LEFT JOIN {{ source('frots', 'stag_sources') }} ss1 ON ss1.old_id = ss.id_pr
LEFT JOIN {{ source('frots', 'view_stag_employees_user') }} employee ON employee.user_id = cl.create_uid AND employee.brand_etl = cl.brand_etl
WHERE cl.active IS TRUE 
  AND cl.create_date >= '{{ start_date }}'::TIMESTAMP
