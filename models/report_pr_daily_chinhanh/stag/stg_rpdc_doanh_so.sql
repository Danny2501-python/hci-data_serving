{{
  config(materialized = 'ephemeral')
}}
-- =============================================================================
-- stg_rpdc_doanh_so
-- Doanh số (DS): metric = doanh_so, date = ngay_tt (ngày thanh toán).
-- Nguồn: stg_common_tongquan_khachhang_sm_pr (brand_etl = 3, Paris).
-- TẠM: filter theo đúng loai_ban_ghi, chưa thêm business rule khác.
-- =============================================================================
SELECT
    'ds' type_report ,
    chinhanhphanquyen,
    chinhanh,
    note,
     ngay_tt,
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
     doanh_so,
     ctg_source_new
FROM {{ ref('stg_common_tongquan_khachhang_sm_pr') }} stks
WHERE /*note not ilike ('%liệu trình%')
and*/ ngay_tt is not NULL