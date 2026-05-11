-- Pass 1.3: Nhân viên seeding từ Caresoft (form không có trong Odoo Seeding)
WITH b AS (
    SELECT
        ticket_id,
        MAX(nhanvien_seeding) AS nhanvien_seeding,
        MAX(created_at)       AS create_date,
        MAX(brand_id)         AS brand_id,
        MAX(phone)            AS phone,
        MAX(customer)         AS customer
    FROM {{ ref('stg_frots_caresoft_tickets') }}
    WHERE nhanvien_seeding IS NOT NULL
      AND nhanvien_seeding NOT IN ('', 'Mặc định')
      AND nhanvien_seeding NOT ILIKE '%test%'
      AND customer NOT ILIKE '%test%'
    GROUP BY ticket_id
)
SELECT
    'form-' || ticket_id            AS ids,
    phone::TEXT                     AS phone,
    'FORM-' || ticket_id            AS tên,
    b.create_date                   AS ngày,
    NULL::TEXT                      AS phieu_thanh_toan,
    'Form'                          AS bảng,
    ticket_id::TEXT                 AS ticket_id,
    b.customer                      AS ten_kh,
    b.nhanvien_seeding              AS nhân_viên,
    CASE
        WHEN b.brand_id = 1 THEN 'Kangnam'
        WHEN b.brand_id = 3 THEN 'Paris'
        WHEN b.brand_id = 4 THEN 'Hồng Hà'
        ELSE b.brand_id::TEXT
    END                             AS thương_hiệu,
    NULL::TEXT                      AS chi_nhánh,
    b.brand_id                      AS thuonghieuphanquyen,
    NULL::TEXT                      AS dịch_vụ,
    NULL::TEXT                      AS nhóm_dịch_vụ,
    NULL::NUMERIC                   AS prepayment_amount,
    NULL::TEXT                      AS payment_type,
    'Seeding (Form)'                AS source,
    NULL::TEXT                      AS page_name,
    NULL::TEXT                      AS page_link,
    NULL::TEXT                      AS doctor,
    NULL::INT                       AS brand_etl,
    NULL::TEXT                      AS create_by,
    NULL::TEXT                      AS create_by_department
FROM b
WHERE NOT EXISTS (
    SELECT 1 FROM {{ ref('stg_frots_seeding_form') }} sf
    WHERE sf.ticket_id::TEXT = b.ticket_id::TEXT
)
