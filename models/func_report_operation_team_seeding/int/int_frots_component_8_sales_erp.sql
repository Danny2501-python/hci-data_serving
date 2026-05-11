-- Pass 8: Doanh số ERP (dịch thẳng từ v1 cte_sales_erp)
-- Company/Brand: từ vctpsp.company_id (không phải cl.company_id)
-- Product: từ vctpsp.product_id (không phải cl2.product_id)
{% set start_date = var('start_date', '2025-08-01') %}

SELECT
    CONCAT(vctpsp.brand_etl, '-', vctpsp.id)            AS ids,
    cl.phone,
    cl.name                                              AS tên,
    vctpsp.payment_date                                  AS ngày,
    vctpsp.ma_phieu                                      AS phieu_thanh_toan,
    'Doanh số'                                           AS bảng,
    cl.ticket_id::TEXT                                   AS ticket_id,
    cl.contact_name                                      AS ten_kh,
    cc.nhanvien_seeding                                  AS "nhân viên",
    rb.name                                              AS "thương hiệu",
    mrc.name                                             AS "chi nhánh",
    rb.id                                                AS thuonghieuphanquyen,
    sp.product                                           AS "dịch vụ",
    sp.product_category                                  AS "nhóm dịch vụ",
    vctpsp.payment                                       AS prepayment_amount,
    vctpsp.payment_type,
    CASE WHEN cl.brand_id = 3 THEN ss1.org_source ELSE ss.source END AS source,
    sf.page_name,
    sf.page_link,
    sf.doctor,
    cl.brand_etl::INT,
    employee.employee                                    AS create_by,
    employee.department                                  AS create_by_department
FROM {{ source('frots', 'stag_payment_transfer') }} vctpsp
LEFT JOIN {{ source('frots', 'crm_lead') }} cl
    ON cl.id = vctpsp.crm_id AND cl.brand_etl = vctpsp.brand_etl
LEFT JOIN {{ source('frots', 'm_res_company') }} mrc
    ON mrc.id = vctpsp.company_id AND mrc.brand_etl = vctpsp.brand_etl
LEFT JOIN {{ source('frots', 'res_brand') }} rb
    ON rb.id = mrc.brand_id AND rb.brand_etl = mrc.brand_etl
LEFT JOIN {{ source('frots', 'view_stag_products') }} sp
    ON vctpsp.product_id = sp.product_id AND vctpsp.brand_etl = sp.brand_etl
LEFT JOIN {{ ref('stg_frots_caresoft_tickets') }} cc
    ON cc.ticket_id::TEXT = cl.ticket_id::TEXT
LEFT JOIN {{ ref('stg_frots_seeding_form') }} sf
    ON sf.ticket_id::TEXT = cl.ticket_id::TEXT
LEFT JOIN {{ source('frots', 'view_stag_employees_user') }} employee
    ON employee.user_id = cl.create_uid AND employee.brand_etl = cl.brand_etl
LEFT JOIN {{ source('frots', 'stag_sources') }} ss
    ON ss.old_id = cl.source_id
LEFT JOIN {{ source('frots', 'stag_sources') }} ss1
    ON ss1.old_id = ss.id_pr
WHERE vctpsp.payment_date::DATE >= '{{ start_date }}'
  AND (CASE WHEN cl.brand_id = 3 THEN ss1.org_source ELSE ss.source END)
      ILIKE ANY (ARRAY['%MD - Phát triển cộng đồng%', '%seeding%', 'MD - Affiliate'])
