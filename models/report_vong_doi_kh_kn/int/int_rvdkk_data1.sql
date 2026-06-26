-- Tương đương bảng tạm data1 trong func_data_vong_doi_khach_hang
-- Lọc: bỏ Lead new và những booking chưa đến cửa

select *
from {{ ref('int_rvdkk_data_final') }}
where crm_type not in ('Lead new')
  and ngay_den_cua is not null
