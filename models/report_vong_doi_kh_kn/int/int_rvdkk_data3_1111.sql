-- Tương đương bảng tạm data3_1111 trong func_data_vong_doi_khach_hang
-- Lọc DV thành công từ data3, gắn thêm key kh_tv

select
    data3.*,
    concat(ma_kh_new, '-', tu_van1_id) as kh_tv
from {{ ref('int_rvdkk_data3') }} data3
where dv_tc = 'DV thành công'
