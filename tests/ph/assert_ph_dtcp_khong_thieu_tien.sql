-- Mọi khoản tiền THẬT trong báo cáo doanh thu + chi phí Philippines phải có số tiền VND.
-- Có dòng trả về = thiếu tỷ giá (doanh thu ngoại tệ mới, hoặc vật tư khi bật
-- ph_vat_tu_don_vi = 'PHP' mà chưa có tỷ giá ngày đó) -> dbt build báo lỗi.
{{ config(severity='error', tags=['phi']) }}

SELECT ngay, nhom, khoan_muc, ma_chung_tu, loai_tien_goc, so_tien_goc, nguon_ty_gia
FROM {{ ref('report_ph_doanh_thu_chi_phi') }}
WHERE trang_thai_du_lieu = 'THAT'
  AND (so_tien_vnd IS NULL OR tac_dong_loi_nhuan IS NULL)
