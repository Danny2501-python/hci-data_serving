{{
  config(
    materialized = 'table',
    schema       = 'sandbox_ph',
    alias        = 'report_ph_sale_online',
    tags         = ['report_ph_sale', 'phi']
  )
}}
-- =============================================================================
-- report_ph_sale_online — báo cáo hiệu suất sale online PHILIPPINES
-- 23 cột đầu giống hệt public.report_kn_sale_online (tên, thứ tự, kiểu) → Tableau chỉ
-- cần đổi nguồn bảng. Thêm 5 cột cuối: trang_thai_du_lieu, ly_do, lead_id,
-- loai_tien, so_tien_goc (2 cột tiền chỉ có giá trị ở nhánh DS).
-- Nhánh (bang): Lead_total / BK / HL / DC / TC / DS – cùng ý nghĩa với KN.
-- Mọi phép đếm/tổng BẮT BUỘC lọc theo `bang` (BK/HL/DC lặp cùng booking) và
-- trang_thai_du_lieu = 'THAT'.
-- =============================================================================
WITH m AS (
    SELECT * FROM {{ ref('stg_phso_map') }}
),
-- Team theo email: ưu tiên bảng team chung (Kangnam), sau đó bảng bổ sung PH.
team AS (
    SELECT lower(work_email) AS work_email, name, group_name, "group"::text AS team_id,
           date(expiration_date) AS expiration_date, 1 AS uu_tien
    FROM {{ source('kso_crm_base', 'table_team_sale_trans_field') }}
    UNION ALL
    SELECT lower(work_email), name, group_name, "group", expiration_date, 2
    FROM {{ source('sandbox_ph', 'team_sale_ph') }}
),
-- Thuộc tính lead (dòng dịch vụ đầu tiên) để gắn cho doanh số
lead_attr AS (
    SELECT DISTINCT ON (lead_id) *
    FROM m ORDER BY lead_id, line_id NULLS LAST
),
rows AS (
    SELECT m.*, 'Lead_total'::text AS bang, m.ngay_tao AS ngay, NULL::text AS ma_phieu,
           m.sdt::text AS gia_tri, NULL::text AS loai_tien, NULL::numeric AS so_tien_goc
    FROM m
    WHERE m.loai_ban_ghi = 1
      AND m.trang_thai IN ('Booked', 'Tiềm năng', 'Consider', 'Số mới')

    UNION ALL
    SELECT m.*, 'BK', m.ngay_tao, NULL, m.sdt, NULL, NULL
    FROM m WHERE m.loai_ban_ghi = 2 AND (m.reason_cancel_booking IS NULL OR m.reason_cancel_booking <> 'tao_booking_bh')

    UNION ALL
    SELECT m.*, 'HL', m.ngay_hl, NULL, m.sdt, NULL, NULL
    FROM m WHERE m.loai_ban_ghi = 2 AND (m.reason_cancel_booking IS NULL OR m.reason_cancel_booking <> 'tao_booking_bh')

    UNION ALL
    SELECT m.*, 'DC', m.ngay_den_cua, NULL, m.sdt, NULL, NULL
    FROM m WHERE m.loai_ban_ghi = 2 AND (m.reason_cancel_booking IS NULL OR m.reason_cancel_booking <> 'tao_booking_bh')

    UNION ALL
    SELECT m.*, 'TC', m.ngay_den_cua, NULL, m.sdt, NULL, NULL
    FROM m WHERE m.loai_ban_ghi = 2 AND (m.reason_cancel_booking IS NULL OR m.reason_cancel_booking <> 'tao_booking_bh')
      AND m.tong_tien > 0

    UNION ALL
    -- DS: theo phiếu thu đã ghi sổ, quy đổi VND bằng seed ucbt_ty_gia_ph
    -- (stg_frmacph_doanh_so_thu – dùng chung với báo cáo marketing PH).
    -- Giống KN: chi nhánh = chi nhánh thu tiền; không loại booking bảo hành.
    SELECT
        la.lead_id, la.line_id, la.loai_ban_ghi, la.vk, la.ten_khach, la.ma_kh, la.sdt, la.ma_booking,
        la.ticket_id, la.ngay_tao, la.ngay_den_cua, la.ngay_hl, la.trang_thai, la.reason_cancel_booking,
        la.nguon, coalesce(d.chi_nhanh, la.chi_nhanh), coalesce(ap.company_id, la.chinhanhphanquyen),
        la.tinh, la.work_email, la.nhom_dv, la.ten_dv, la.his_service_type, la.surgery_type, la.tong_tien,
        coalesce(la.trang_thai_du_lieu, 'NGHI_TEST'), coalesce(la.ly_do, 'Phiếu thu không gắn lead'),
        'DS', d.ngay, ap.name, d.doanh_so::text, d.loai_tien, d.so_tien_goc
    FROM {{ ref('stg_frmacph_doanh_so_thu') }} d
    LEFT JOIN {{ source('ph', 'account_payment') }} ap ON ap.id = d.payment_id
    LEFT JOIN lead_attr la ON la.lead_id = d.lead_id
)
SELECT
    'page'::text                              AS page,
    'ad'::text                                AS ad_id,
    r.bang::text                              AS bang,
    r.ticket_id::text                         AS ticket_id,
    r.gia_tri::varchar                        AS sdt,            -- DS: doanh số VND (giống KN)
    upper(tts.name)::text                     AS nhan_vien_tts,
    tts.group_name::text                      AS nhom_nv,
    tts.team_id::text                         AS team_id,
    r.ngay::date                              AS "date",
    r.nguon::varchar                          AS nguon,
    r.chi_nhanh::varchar                      AS chi_nhanh,
    r.nhom_dv::text                           AS nhom_dv,
    r.his_service_type::text                  AS his_service_type,
    r.work_email::text                        AS work_email,
    r.ten_khach::varchar                      AS ten_khach,
    r.ma_kh::varchar                          AS ma_kh,
    r.ma_booking::varchar                     AS ma_booking,
    r.surgery_type::text                      AS surgery_type,
    r.tinh::varchar                           AS tinh,
    r.chinhanhphanquyen::integer              AS chinhanhphanquyen,
    r.ten_dv::text                            AS ten_dv,
    r.ma_phieu::varchar                       AS ma_phieu,
    r.vk::varchar                             AS vk,
    -- cột thêm
    coalesce(r.trang_thai_du_lieu, 'NGHI_TEST')::text AS trang_thai_du_lieu,
    r.ly_do::text                             AS ly_do,
    r.lead_id::integer                        AS lead_id,
    r.loai_tien::text                         AS loai_tien,
    r.so_tien_goc::numeric                    AS so_tien_goc
FROM rows r
LEFT JOIN LATERAL (
    -- team có hiệu lực tại ngày của nhánh (giống KN); ưu tiên bảng team chung
    SELECT t.name, t.group_name, t.team_id
    FROM team t
    WHERE t.work_email = r.work_email
      AND t.expiration_date >= r.ngay
    ORDER BY t.uu_tien, t.expiration_date
    LIMIT 1
) tts ON TRUE
