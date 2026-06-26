-- Tương đương bảng tạm data4 trong func_data_vong_doi_khach_hang
-- Đánh dấu check_tv_rk1:
--   'T' nếu tư vấn viên (kh_tv) đã từng có DV TC ở lần đến cửa đầu tiên
--   'F' nếu không

select *, 'T' as check_tv_rk1
from {{ ref('int_rvdkk_data3_1111') }} d
where exists (
    select 1 from {{ ref('int_rvdkk_tv_rnk1') }} t
    where d.kh_tv = t.kh_tv
)

union all

select *, 'F' as check_tv_rk1
from {{ ref('int_rvdkk_data3_1111') }} d
where not exists (
    select 1 from {{ ref('int_rvdkk_tv_rnk1') }} t
    where d.kh_tv = t.kh_tv
)
