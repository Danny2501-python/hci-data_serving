-- Tương đương bảng tạm min_false trong func_data_vong_doi_khach_hang
-- Tìm stt nhỏ nhất có check_rnk_ago = 'F' (điểm gãy đầu tiên) cho mỗi kh_tv

select
    kh_tv,
    min(stt) as min_value
from {{ ref('int_rvdkk_stt_table') }}
where check_rnk_ago = 'F'
group by kh_tv
