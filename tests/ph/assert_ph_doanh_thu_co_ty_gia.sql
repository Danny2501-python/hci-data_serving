-- Phiếu thu THẬT của Philippines phải quy đổi được ra VND.
-- Có dòng trả về = thiếu tỷ giá (loại tiền mới, hoặc bảng public.ty_gia_acb chưa có ngày đó
-- khi bật var ph_nguon_ty_gia = 'acb') -> dbt build báo lỗi thay vì âm thầm tính thiếu doanh thu.
{{ config(severity='error', tags=['phi']) }}

SELECT payment_id, ma_phieu, ngay_thu, loai_tien, so_tien_goc, nguon_ty_gia
FROM {{ ref('report_ph_doanh_thu') }}
WHERE trang_thai_du_lieu = 'THAT'
  AND (ty_gia IS NULL OR doanh_thu_vnd IS NULL)
