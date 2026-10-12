{{
  config(
    materialized = 'table',
    schema       = 'sandbox_ph',
    alias        = 'report_ph_tqdskh_khach',
    tags         = ['report_ph_tq_ds_kh', 'phi']
  )
}}
-- =============================================================================
-- report_ph_tqdskh_khach — thay "Custom SQL Query" của workbook
-- "TỔNG QUAN DOANH SỐ VÀ KHÁCH HÀNG MKT KANGNAM (FULL)" cho Sunwoo Philippines.
-- Cùng tên cột / thứ tự / kiểu với câu SQL Kangnam để Tableau chỉ cần đổi nguồn.
--   bang = 'data'    : lead × dòng dịch vụ (Lead / Booking / Đến cửa / Thành công)
--   bang = 'payment' : 1 dòng / phiếu thu, doanh số VND (stg_frmacph_doanh_so_thu, tỷ giá ACB)
-- Chỉ dữ liệu THAT. Xem README.md cùng thư mục.
-- =============================================================================
WITH lead AS (
    SELECT * FROM {{ ref('stg_phtq_lead') }}
),
line AS (
    SELECT * FROM {{ ref('stg_phtq_line') }}
),
ds AS (
    SELECT * FROM {{ ref('stg_frmacph_doanh_so_thu') }}
),
khach AS (
    SELECT
        l.viet_kieu                                         AS "Việt Kiều/Nội Địa",
        ln.code_dv,
        l.ten_khach,
        l.lead_id                                           AS id,
        l.ma_kh,
        l.sdt,
        l.ngay_den_cua::timestamp                           AS ngay_den_cua,
        l.loai_ban_ghi,
        l.ngay_tao::timestamp                               AS ngay_tao,
        l.ngay_den_cua::timestamp                           AS ngay_dc,
        l.ngay_hl::timestamp                                AS ngay_hl,
        DATE '9999-01-01'                                   AS ngay_tt,
        coalesce(l.ngay_den_cua, l.ngay_tao)                AS date_time,
        l.ma_booking,
        l.nhan_vien,
        0::float                                            AS doanh_so,
        l.amount_paid::float                                AS tong_tien,
        'not'::text                                         AS vao_so,
        l.trang_thai,
        ln.line_tt,
        CASE WHEN l.ngay_den_cua IS NOT NULL
              AND l.trang_thai IN ('Won', 'Đặt cọc', 'Đang xử lý')   THEN 'Thành Công'
             WHEN l.ngay_den_cua IS NOT NULL                          THEN 'Đến Cửa'
             WHEN l.loai_ban_ghi = 2                                  THEN 'Booking'
             WHEN l.loai_ban_ghi = 1                                  THEN 'Lead'
        END                                                 AS phan_loai_khach,
        l.loai_bk,
        'Sunwoo'::text                                      AS thuong_hieu,
        ln.nhom_dv,
        ln.ten_dv,
        l.chi_nhanh,
        l.company_id                                        AS chinhanhphanquyen_notuse,
        l.create_by_department::text                        AS phong_ban_nguoi_tao,
        l.nguon                                             AS nguon_moi,
        l.nhom_nguon                                        AS nhom_nguon_moi,
        l.loai_bk                                           AS "LoaiKH",
        l.type_data_partner::text                           AS type_data_partner,
        l.ten_cd,
        l.kenh,
        l.ma_kenh::float                                    AS ma_kenh,
        l.nhom_kenh                                         AS nguon_moi_new,
        CASE l.nhom_kenh WHEN 'Marketing Digital'  THEN 1 WHEN 'Marketing Offline' THEN 2
                         WHEN 'Marketing Location' THEN 3 WHEN 'Nguồn khác'        THEN 4
        END                                                 AS ma_nguon_moi_new,
        ln.line_id                                          AS clineid,
        CASE WHEN ln.nhom_dv = 'SAN PHAM' THEN 'Sản Phẩm'
             ELSE ln.his_service_type END                   AS his_service_type,
        'abc'::text                                         AS ma_phieu,
        NULL::text                                          AS loai_pt,
        l.type::text                                        AS lead_or_oppor,
        'abc'::text                                         AS fk_id,
        0                                                   AS spt_cline,
        'data'::text                                        AS bang,
        NULL::float                                         AS quantity,
        NULL::integer                                       AS number_used,
        0                                                   AS "?column?"
    FROM lead l
    LEFT JOIN line ln ON ln.lead_id = l.lead_id
),
thanh_toan AS (
    SELECT
        l.viet_kieu,
        ln.code_dv,
        l.ten_khach,
        l.lead_id                                           AS id,
        l.ma_kh,
        l.sdt,
        l.ngay_den_cua::timestamp,
        l.loai_ban_ghi,
        l.ngay_tao::timestamp,
        l.ngay_den_cua::timestamp,
        l.ngay_hl::timestamp,
        d.ngay::date,
        d.ngay::date,
        l.ma_booking,
        l.nhan_vien,
        d.doanh_so::float,
        ln.tong_tien_line::float,
        'posted'::text,
        'Won'::text,
        'done'::text,
        'Booking'::text,
        'Paid'::text,
        'Sunwoo'::text,
        ln.nhom_dv,
        ln.ten_dv,
        d.chi_nhanh,
        ap.company_id,
        l.create_by_department::text,
        l.nguon,
        l.nhom_nguon,
        'Booking new'::text,
        'old'::text,
        l.ten_cd,
        l.nguon,
        l.ma_kenh::float,
        l.nhom_kenh,
        CASE l.nhom_kenh WHEN 'Marketing Digital'  THEN 1 WHEN 'Marketing Offline' THEN 2
                         WHEN 'Marketing Location' THEN 3 WHEN 'Nguồn khác'        THEN 4
        END,
        ln.line_id,
        ln.his_service_type,
        ap.name::text,
        NULL::text,
        'opportunity'::text,
        d.payment_id::text,
        ln.line_id,
        'payment'::text,
        ln.quantity::float,
        ln.number_used::integer,
        99
    FROM ds d
    JOIN lead l                                         ON l.lead_id = d.lead_id
    LEFT JOIN line ln                                   ON ln.lead_id = d.lead_id AND ln.rn_lead = 1
    LEFT JOIN {{ source('ph', 'account_payment') }} ap  ON ap.id = d.payment_id
)
SELECT * FROM khach
UNION ALL
SELECT * FROM thanh_toan
