-- Pass 7: Thành công (dịch thẳng từ v1 cte_success)
{% set start_date = var('start_date', '2025-08-01') %}

SELECT
    cl.brand_etl || '-tc-' || cl.id                     AS ids,
    cl.phone,
    cl.name                                              AS tên,
    cl.arrival_date + INTERVAL '7 hours'                AS ngày,
    ap.name                                              AS phieu_thanh_toan,
    'Thành công'                                         AS bảng,
    cl.ticket_id::TEXT                                   AS ticket_id,
    cl.contact_name                                      AS ten_kh,
    cc.nhanvien_seeding                                  AS nhân_viên,
    rb.name                                              AS thương_hiệu,
    res_c.name                                           AS chi_nhánh,
    rb.id                                                AS thuonghieuphanquyen,
    sp.product                                           AS dịch_vụ,
    sp.product_category                                  AS nhóm_dịch_vụ,
    capd.prepayment_amount,
    ap.payment_type,
    CASE WHEN cl.brand_id = 3 THEN ss1.org_source ELSE ss.source END AS source,
    sf.page_name,
    sf.page_link,
    sf.doctor,
    cl.brand_etl::INT,
    employee.employee                                    AS create_by,
    employee.department                                  AS create_by_department
FROM {{ source('frots', 'crm_lead') }} cl
JOIN {{ source('frots', 'crm_line') }} cl2
    ON cl2.crm_id = cl.id AND cl2.brand_etl = cl.brand_etl
JOIN {{ source('frots', 'crm_account_payment_detail') }} capd
    ON cl2.id = capd.crm_line_id AND cl2.brand_etl = capd.brand_etl
JOIN {{ source('frots', 'account_payment') }} ap
    ON ap.id = capd.account_payment_id AND ap.brand_etl = capd.brand_etl
LEFT JOIN {{ ref('stg_frots_caresoft_tickets') }} cc
    ON cc.ticket_id::TEXT = cl.ticket_id::TEXT
LEFT JOIN {{ ref('stg_frots_seeding_form') }} sf
    ON sf.ticket_id::TEXT = cl.ticket_id::TEXT
LEFT JOIN {{ source('frots', 'view_stag_employees_user') }} employee
    ON employee.user_id = cl.create_uid AND employee.brand_etl = cl.brand_etl
LEFT JOIN {{ source('frots', 'view_stag_products') }} sp
    ON cl2.product_id = sp.product_id AND cl2.brand_etl = sp.brand_etl
LEFT JOIN {{ source('frots', 'm_res_company') }} res_c
    ON res_c.id = cl.company_id AND res_c.brand_etl = cl.brand_etl
LEFT JOIN {{ source('frots', 'res_brand') }} rb
    ON rb.id = res_c.brand_id AND rb.brand_etl = res_c.brand_etl
LEFT JOIN {{ source('frots', 'stag_sources') }} ss
    ON ss.old_id = cl.source_id
LEFT JOIN {{ source('frots', 'stag_sources') }} ss1
    ON ss1.old_id = ss.id_pr
WHERE cl.active IS TRUE
  AND cl.type = 'opportunity'
  AND cl.arrival_date >= '{{ start_date }}'::TIMESTAMP
  AND ap.state = 'posted'
  AND capd.prepayment_amount > 0
  AND (CASE WHEN cl.brand_id = 3 THEN ss1.org_source ELSE ss.source END)
      ILIKE ANY (ARRAY['%MD - Phát triển cộng đồng%', '%seeding%', 'MD - Affiliate'])
