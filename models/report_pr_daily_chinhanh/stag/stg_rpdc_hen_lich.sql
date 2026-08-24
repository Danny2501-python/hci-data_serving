{{
  config(materialized = 'ephemeral')
}}
-- =============================================================================
-- stg_rpdc_hen_lich
-- Hẹn lịch (HL): loại trừ bản ghi Lead, date = ngay_hl.
-- Nguồn: stg_common_tongquan_khachhang_sm_pr (brand_etl = 3, Paris).
-- TẠM: filter theo đúng loai_ban_ghi, chưa thêm business rule khác.
-- =============================================================================
SELECT
    'hl' type_report ,
    chinhanhphanquyen,
    chinhanh,
    note,
     ngay_hl,
     ten_khach,
     ma_kh,
     ma_booking,
     phan_loai_dv,
     nhom_dv,
     nhom_dv_dc,
       dv_trong_tam,
     loai_ban_ghi,
     nguon_moi nguon,
     source_new,
     sdt,
     tong_tien,
     ctg_source_new
FROM {{ ref('stg_common_tongquan_khachhang_sm_pr') }} stks
WHERE ngay_hl is not null
  AND loai_ban_ghi <> 1
--and note not ilike ('%liệu trình%')