{{ config(
    materialized='table',
    alias='report_operation_team_seeding',
    tags=['report_frots']
) }}

{% set start_date = var('start_date', '2025-08-01') %}

WITH 
-- Lấy Base Data đã lọc theo Source Seeding
cte_seeding_leads AS (
    SELECT * FROM {{ ref('int_frots_base_lead') }}
    WHERE source_name ILIKE ANY (ARRAY['%MD - Phát triển cộng đồng%', '%seeding%', 'MD - Affiliate'])
),

final_output AS (
    -- Pass 1.3: Nhân viên seeding trên caresoft (lấy form)
    SELECT
        'form-' || ticket_id AS ids,
        phone::TEXT,
        'FORM-' || ticket_id AS tên,
        MAX(created_at) AS ngày,
        NULL AS phieu_thanh_toan,
        'Form' AS bảng,
        ticket_id::TEXT,
        MAX(customer) AS ten_kh,
        MAX(nhanvien_seeding) AS nhân_viên,
        CASE 
            WHEN MAX(brand_id) = 1 THEN 'Kangnam'
            WHEN MAX(brand_id) = 3 THEN 'Paris'
            WHEN MAX(brand_id) = 4 THEN 'Hồng Hà'
            ELSE MAX(brand_id)::TEXT
        END AS thương_hiệu,
        NULL AS chi_nhánh,
        MAX(brand_id) AS thuonghieuphanquyen,
        NULL AS dịch_vụ,
        NULL AS nhóm_dịch_vụ,
        NULL::NUMERIC AS prepayment_amount,
        NULL AS payment_type,
        'Seeding (Form)' AS source,
        NULL AS page_name, NULL AS page_link, NULL AS doctor, NULL::INT AS brand_etl, NULL AS create_by, NULL AS create_by_department
    FROM {{ ref('stg_frots_caresoft_tickets') }} b
    WHERE nhanvien_seeding IS NOT NULL AND nhanvien_seeding NOT IN ('', 'Mặc định')
      AND nhanvien_seeding NOT ILIKE '%test%' AND customer NOT ILIKE '%test%'
      AND NOT EXISTS (SELECT 1 FROM {{ ref('stg_frots_seeding_form') }} sf WHERE sf.ticket_id::TEXT = b.ticket_id::TEXT)
    GROUP BY ticket_id, phone

    UNION ALL

    -- Pass 2: Tạo bảng form Odoo
    SELECT 
        rb.brand_etl || '-form-' || sf.id,
        TRIM(REPLACE(sf.phone, ' ', '')),
        sf.code_form,
        sf.create_date + INTERVAL '7 hours',
        NULL, 'Form', sf.ticket_id::TEXT, sf.name, su.name, rb.name, mrc.name, rb.id,
        TRIM(UPPER(REGEXP_REPLACE(sf.service, '\s+', ' ', 'g'))),
        NULL, NULL, NULL, 'Seeding (Form)', sf.page_name, sf.page_link, sf.doctor, NULL, NULL, NULL
    FROM {{ ref('stg_frots_seeding_form') }} sf 
    LEFT JOIN {{ source('frots', 'seeding_user') }} su ON su.id = sf.user_id
    LEFT JOIN {{ source('frots', 'seeding_res_company') }} src ON sf.company_id = src.id
    LEFT JOIN {{ source('frots', 'm_res_company') }} mrc ON mrc.company_code = src.code AND mrc.brand_etl = 7
    LEFT JOIN {{ source('frots', 'res_brand') }} rb ON rb.id = mrc.brand_id AND rb.brand_etl = 7
    WHERE rb.id NOT IN (2,5,4)

    UNION ALL

    -- Pass 3: Lead
    SELECT 
        brand_etl || '-lead-' || lead_id, phone, lead_name, create_date + INTERVAL '7 hours',
        NULL, 'Lead', ticket_id::TEXT, contact_name, nhanvien_seeding, brand_name, company_name, rb_id, product, product_category,
        NULL, NULL, source_name, page_name, page_link, doctor, brand_etl, employee, department
    FROM cte_seeding_leads
    WHERE lead_type = 'lead' AND stage_id IN (8, 18, 7)

    UNION ALL

    -- Pass 4: Booking
    SELECT 
        brand_etl || '-book-' || lead_id, phone, lead_name, create_date + INTERVAL '7 hours',
        NULL, 'Booking', ticket_id::TEXT, contact_name, nhanvien_seeding, brand_name, company_name, rb_id, product, product_category,
        NULL, NULL, source_name, page_name, page_link, doctor, brand_etl, employee, department
    FROM cte_seeding_leads
    WHERE lead_type = 'opportunity'

    UNION ALL

    -- Pass 5: Booking Date
    SELECT 
        brand_etl || '-bookd-' || lead_id, phone, lead_name, booking_date + INTERVAL '7 hours',
        NULL, 'Booking date', ticket_id::TEXT, contact_name, nhanvien_seeding, brand_name, company_name, rb_id, product, product_category,
        NULL, NULL, source_name, page_name, page_link, doctor, brand_etl, employee, department
    FROM cte_seeding_leads
    WHERE lead_type = 'opportunity' AND booking_date IS NOT NULL

    UNION ALL

    -- Pass 6: Đến cửa
    SELECT 
        brand_etl || '-đc-' || lead_id, phone, lead_name, arrival_date + INTERVAL '7 hours',
        NULL, 'Đến cửa', ticket_id::TEXT, contact_name, nhanvien_seeding, brand_name, company_name, rb_id, product, product_category,
        NULL, NULL, source_name, page_name, page_link, doctor, brand_etl, employee, department
    FROM cte_seeding_leads
    WHERE lead_type = 'opportunity' AND arrival_date >= '{{ start_date }}'::TIMESTAMP

    UNION ALL

    -- Pass 7: Thành công (Join thêm payment)
    SELECT
        cl.brand_etl || '-tc-' || cl.lead_id, cl.phone, cl.lead_name, cl.arrival_date + INTERVAL '7 hours',
        ap.name, 'Thành công', cl.ticket_id::TEXT, cl.contact_name, cl.nhanvien_seeding, cl.brand_name, cl.company_name, cl.rb_id, cl.product, cl.product_category,
        capd.prepayment_amount, ap.payment_type, cl.source_name, cl.page_name, cl.page_link, cl.doctor, cl.brand_etl, cl.employee, cl.department
    FROM cte_seeding_leads cl
    JOIN {{ source('frots', 'crm_line') }} cl2 ON cl2.crm_id = cl.lead_id AND cl2.brand_etl = cl.brand_etl
    JOIN {{ source('frots', 'crm_account_payment_detail') }} capd ON cl2.id = capd.crm_line_id AND cl2.brand_etl = capd.brand_etl
    JOIN {{ source('frots', 'account_payment') }} ap ON ap.id = capd.account_payment_id AND ap.brand_etl = capd.brand_etl
    WHERE cl.lead_type = 'opportunity' AND cl.arrival_date >= '{{ start_date }}'::TIMESTAMP
      AND ap.state = 'posted' AND capd.prepayment_amount > 0

    UNION ALL

    -- Pass 8: Doanh số ERP
    SELECT
        vctpsp.brand_etl || '-' || vctpsp.id, cl.phone, cl.lead_name, vctpsp.payment_date,
        vctpsp.ma_phieu, 'Doanh số', cl.ticket_id::TEXT, cl.contact_name, cl.nhanvien_seeding, cl.brand_name, cl.company_name, cl.rb_id, cl.product, cl.product_category,
        vctpsp.payment, vctpsp.payment_type, cl.source_name, cl.page_name, cl.page_link, cl.doctor, cl.brand_etl, cl.employee, cl.department
    FROM {{ source('frots', 'stag_payment_transfer') }} vctpsp 
    LEFT JOIN {{ ref('int_frots_base_lead') }} cl ON cl.lead_id = vctpsp.crm_id AND cl.brand_etl = vctpsp.brand_etl
    WHERE vctpsp.payment_date::DATE >= '{{ start_date }}'
      AND cl.source_name ILIKE ANY (ARRAY['%MD - Phát triển cộng đồng%', '%seeding%', 'MD - Affiliate'])
)

SELECT * FROM final_output
