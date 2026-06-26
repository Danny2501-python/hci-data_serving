-- Tương đương bảng tạm tv_rnk1 trong func_data_vong_doi_khach_hang
-- Lấy ra key kh_tv của những tư vấn viên có DV thành công ngay ở lần đến cửa đầu tiên (rnk = 1)

select concat(ma_kh_new, '-', tu_van1_id) as kh_tv
from {{ ref('int_rvdkk_data3') }}
where dv_tc = 'DV thành công'
  and rnk = 1
