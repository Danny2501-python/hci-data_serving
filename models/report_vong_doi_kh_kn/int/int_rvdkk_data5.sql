-- Tương đương bảng tạm data5 trong func_data_vong_doi_khach_hang
-- Đánh dấu check_rnk_ago:
--   'F' nếu rank bị nhảy cóc (gãy chuỗi liên tục với tư vấn viên trước)
--   'T' nếu rank liên tục

select
    data4.*,
    case when rnk - coalesce(lead(rnk, 1) over (partition by kh_tv order by rnk desc), 0) > 1
         then 'F'
         else 'T'
    end as check_rnk_ago
from {{ ref('int_rvdkk_data4') }} data4
where check_tv_rk1 = 'T'

union all

select data4.*, 'F' as check_rnk_ago
from {{ ref('int_rvdkk_data4') }} data4
where check_tv_rk1 = 'F'
