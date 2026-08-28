{{
  config(materialized = 'ephemeral')
}}
-- =============================================================================
-- stg_rpdc_den_cua
-- Đến cửa (TC): khách có doanh_so > 0, date = ngay_den_cua.
-- Nguồn: stg_common_tongquan_khachhang_sm_pr (brand_etl = 3, Paris).
-- TẠM: filter theo đúng loai_ban_ghi/doanh_so, chưa thêm business rule khác.
-- =============================================================================
SELECT
    'dc' type_report,
    chinhanhphanquyen,
    chinhanh,
    note,
     ngay_den_cua,
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
WHERE ngay_den_cua is not null
---and note not ilike ('%liệu trình%')
