-- =============================================================================
-- int_bsp_crm_union  (Pass 5–10)
-- UNION ALL 6 stream CRM từ stg_bsp_crm_base.
-- Cột 4 (requester_id) giữ: sdt cho Lead/BK/HL/DC/TC, text(doanh_so) cho DS.
-- DS dùng phong_ban_nguoi_tao1 thay vì phong_ban_nguoi_tao.
-- =============================================================================

-- Lead_total (Pass 5): loai_ban_ghi=1, trang_thai hợp lệ, nhom_dv không phải Sản Phẩm

WITH base AS MATERIALIZED (
    SELECT *
    FROM {{ ref('stg_bsp_crm_base') }}
    WHERE nhom_dv IS NOT NULL
      AND nhom_dv NOT IN ('SAN PHAM', 'Sản Phẩm')
)
SELECT
    'ad'::text                        AS ad_id,
    'Lead_total'::text                AS bang,
    ticket_id,
    sdt                               AS requester_id,
    nv,
    work_email,
    DATE(ngay_tao)                    AS date,
    nguon,
    chinhanh                          AS chi_nhanh,
    nhom_dv,
    ten_khach,
    ma_booking,
    phong_ban_nguoi_tao               AS phong_ban
FROM base
WHERE loai_ban_ghi = 1
  AND trang_thai IN ('Tiềm năng', 'Tham khảo', 'Đặt lịch')
  -- AND nhom_dv <> 'Sản Phẩm'
  -- AND nhom_dv IS NOT NULL

UNION ALL

-- BK - Booking (Pass 6): loai_ban_ghi=2
SELECT
    'ad'::text,
    'BK'::text,
    ticket_id,
    sdt,
    nv,
    work_email,
    DATE(ngay_tao),
    nguon,
    chinhanh,
    nhom_dv,
    ten_khach,
    ma_booking,
    phong_ban_nguoi_tao
FROM base
WHERE loai_ban_ghi = 2
  -- AND nhom_dv <> 'SAN PHAM'
  -- AND nhom_dv IS NOT NULL

UNION ALL

-- HL - Hẹn lịch (Pass 7): date = ngay_hl
SELECT
    'ad'::text,
    'HL'::text,
    ticket_id,
    sdt,
    nv,
    work_email,
    DATE(ngay_hl),
    nguon,
    chinhanh,
    nhom_dv,
    ten_khach,
    ma_booking,
    phong_ban_nguoi_tao
FROM base
WHERE loai_ban_ghi = 2
  -- AND nhom_dv <> 'SAN PHAM'
  -- AND nhom_dv IS NOT NULL

UNION ALL

-- DC - Đến cửa (Pass 8): date = ngay_dc
SELECT
    'ad'::text,
    'DC'::text,
    ticket_id,
    sdt,
    nv,
    work_email,
    DATE(ngay_dc),
    nguon,
    chinhanh,
    nhom_dv,
    ten_khach,
    ma_booking,
    phong_ban_nguoi_tao
FROM base
WHERE loai_ban_ghi = 2
  -- AND nhom_dv <> 'SAN PHAM'
  -- AND nhom_dv IS NOT NULL

UNION ALL

-- TC - Thành công (Pass 9): doanh_so > 0, date = ngay_den_cua
SELECT
    'ad'::text,
    'TC'::text,
    ticket_id,
    sdt,
    nv,
    work_email,
    DATE(ngay_den_cua),
    nguon,
    chinhanh,
    nhom_dv,
    ten_khach,
    ma_booking,
    phong_ban_nguoi_tao
FROM base
WHERE loai_ban_ghi = 2
  AND doanh_so > 0
  -- AND nhom_dv <> 'SAN PHAM'
  -- AND nhom_dv IS NOT NULL

UNION ALL

-- DS - Doanh số (Pass 10): metric = doanh_so, date = ngay_tt, phong_ban từ _tao1
SELECT
    'ad'::text,
    'DS'::text,
    ticket_id,
    TEXT(doanh_so)                    AS requester_id,
    nv,
    work_email,
    DATE(ngay_tt),
    nguon,
    chinhanh,
    nhom_dv,
    ten_khach,
    ma_booking,
    phong_ban_nguoi_tao1              AS phong_ban
FROM base
WHERE loai_ban_ghi = 2
  -- AND nhom_dv <> 'SAN PHAM'
  -- AND nhom_dv IS NOT NULL
