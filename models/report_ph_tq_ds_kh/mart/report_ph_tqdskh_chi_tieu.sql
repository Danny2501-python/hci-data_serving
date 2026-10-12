{{
  config(
    materialized = 'table',
    schema       = 'sandbox_ph',
    alias        = 'report_ph_tqdskh_chi_tieu',
    tags         = ['report_ph_tq_ds_kh', 'phi']
  )
}}
-- =============================================================================
-- report_ph_tqdskh_chi_tieu — thay "Custom SQL Query2" (chỉ tiêu) của workbook Kangnam.
-- Nguồn: seed target_sunwoo_chitieu; chỉ lấy lần ban hành mới nhất của mỗi
-- tháng × chi nhánh × nguồn × kênh (giống KN). Tên cột giữ nguyên như target_kangnam_chitieu.
-- =============================================================================
WITH ct AS (
    SELECT * FROM {{ ref('target_sunwoo_chitieu') }}
),
max_ban_hanh AS (
    SELECT time, company_id, coalesce(id_nguon, '0') AS id_nguon, coalesce(id_kenh, '0') AS id_kenh,
           max(ngay_ban_hanh) AS max_ban_hanh
    FROM ct
    GROUP BY 1, 2, 3, 4
)
SELECT
    m.time::timestamp                                       AS "time",
    m.brand_id::float                                       AS brand_id,
    m.thuong_hieu                                           AS "thương hiệu",
    m.company_id::float                                     AS company_id,
    m.chi_nhanh                                             AS "chi nhánh",
    m.chi_tieu::float                                       AS "chỉ tiêu",
    m.loai_chi_tieu::float                                  AS "loại chỉ tiêu",
    m.ngay_ban_hanh::timestamp                              AS "ngày ban hành",
    m.id_nguon,
    m.nguon,
    m.id_kenh,
    m.kenh,
    m.ti_trong_nguon,
    m.ti_trong_kenh,
    (m.chi_tieu * replace(m.ti_trong_nguon, ',', '.')::numeric)::float AS chi_tieu_nguon,
    (m.chi_tieu * replace(m.ti_trong_kenh,  ',', '.')::numeric)::float AS chi_tieu_kenh,
    m.chi_tieu::float                                       AS "Chỉ tiêu"
FROM ct m
JOIN max_ban_hanh b ON b.time = m.time
                   AND b.company_id = m.company_id
                   AND b.id_nguon = coalesce(m.id_nguon, '0')
                   AND b.id_kenh  = coalesce(m.id_kenh, '0')
                   AND b.max_ban_hanh = m.ngay_ban_hanh
