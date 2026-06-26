-- Tương đương bảng tạm stt_table trong func_data_vong_doi_khach_hang
-- Đánh số thứ tự (stt) trong mỗi nhóm kh_tv, sắp xếp theo rnk rồi check_rnk_ago

select
    *,
    row_number() over (partition by kh_tv order by rnk, check_rnk_ago) as stt
from {{ ref('int_rvdkk_data5') }}
