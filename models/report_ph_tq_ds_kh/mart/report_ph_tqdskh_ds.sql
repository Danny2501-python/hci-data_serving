{{
  config(
    materialized = 'table',
    schema       = 'sandbox_ph',
    alias        = 'report_ph_tqdskh_ds',
    tags         = ['report_ph_tq_ds_kh', 'phi']
  )
}}
-- =============================================================================
-- report_ph_tqdskh_ds — thay "Custom SQL Query1" (doanh số + chỉ tiêu) của workbook Kangnam.
--   bang = 'Ao' : dòng chỉ tiêu (report_ph_tqdskh_chi_tieu) để map chỉ tiêu
--   bang = 'DV' : 1 dòng / phiếu thu, Thanh_toan = doanh số VND / 1000 (giống KN)
-- Phiếu thu ERP PH gắn theo lead → dịch vụ = dòng dịch vụ đầu tiên của lead.
-- =============================================================================
WITH lead AS (
    SELECT * FROM {{ ref('stg_phtq_lead') }}
),
line AS (
    SELECT * FROM {{ ref('stg_phtq_line') }} WHERE rn_lead = 1
),
ds AS (
    SELECT * FROM {{ ref('stg_frmacph_doanh_so_thu') }}
),
ao AS (
    SELECT
        'Ao'::text                                          AS bang,
        0                                                   AS id_source,
        gts."time"::date                                    AS "Ngay",
        NULL::text                                          AS "Booking",
        NULL::text                                          AS dien_thoai,
        NULL::text                                          AS loai_kh,
        NULL::integer                                       AS "ID",
        NULL::text                                          AS "Phieu",
        gts.kenh                                            AS "Nguon",
        CASE WHEN gts.nguon = 'Nguồn khác' THEN 'Khác' ELSE gts.nguon END AS "Nhom_nguon",
        NULL::text                                          AS "DV/SP",
        NULL::text                                          AS service_code,
        NULL::text                                          AS "Loai_DV/SP",
        NULL::text                                          AS "Nhom_DV",
        gts."thương hiệu"                                   AS "Thuong_hieu",
        gts.brand_id::float                                 AS brandid,
        gts."chi nhánh"                                     AS "Chi_nhanh",
        gts.company_id::float                               AS chinhanhphanquyen_nu,
        0::float                                            AS "Thanh_toan",
        0::float                                            AS "Tong_tien",
        NULL::text                                          AS "TT_DV/SP",
        NULL::text                                          AS "Loai",
        gts.kenh                                            AS kenh,
        gts.id_kenh::float                                  AS ma_kenh,
        CASE WHEN gts.nguon = 'Nguồn khác' THEN 'Khác' ELSE gts.nguon END AS nguon_moi,
        gts.id_nguon::integer                               AS ma_nguon_moi,
        NULL::text                                          AS loai_phau_thuat
    FROM {{ ref('report_ph_tqdskh_chi_tieu') }} gts
),
dv AS (
    SELECT
        'DV'::text,
        l.source_id::integer,
        d.ngay::date,
        l.ma_booking,
        l.sdt,
        l.type_data_partner::text,
        ln.line_id,
        ap.name::text,
        l.nguon,
        l.nhom_nguon,
        ln.ten_dv,
        ln.code_dv,
        ln.his_service_type,
        ln.nhom_dv,
        'Sunwoo'::text,
        NULL::float,
        d.chi_nhanh,
        ap.company_id::float,
        (d.doanh_so / 1000.0)::float,
        ln.tong_tien_line::float,
        ln.line_tt,
        CASE WHEN ap.name LIKE '%PDC%' THEN 'Transfer' ELSE ap.name END,
        l.kenh,
        l.ma_kenh::float,
        l.nhom_kenh,
        CASE l.nhom_kenh WHEN 'Marketing Digital'  THEN 1 WHEN 'Marketing Offline' THEN 2
                         WHEN 'Marketing Location' THEN 3 WHEN 'Nguồn khác'        THEN 4
        END,
        NULL::text
    FROM ds d
    JOIN lead l                                         ON l.lead_id = d.lead_id
    LEFT JOIN line ln                                   ON ln.lead_id = d.lead_id
    LEFT JOIN {{ source('ph', 'account_payment') }} ap  ON ap.id = d.payment_id
    WHERE d.doanh_so <> 0
)
SELECT * FROM ao
UNION ALL
SELECT * FROM dv
