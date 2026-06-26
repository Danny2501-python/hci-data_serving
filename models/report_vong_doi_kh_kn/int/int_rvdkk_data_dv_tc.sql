-- Tương đương bảng tạm data_dv_tc trong func_data_vong_doi_khach_hang
-- Gắn final_result:
--   'F' = từ điểm gãy trở đi (không còn tính cho tư vấn viên này)
--   'T' = trước điểm gãy (hợp lệ)

select stt_table.*, 'F' as final_result
from {{ ref('int_rvdkk_stt_table') }} stt_table
where exists (
    select 1 from {{ ref('int_rvdkk_min_false') }} min_false
    where stt_table.kh_tv = min_false.kh_tv
      and stt_table.stt  >= min_false.min_value
)

union all

select stt_table.*, 'T' as final_result
from {{ ref('int_rvdkk_stt_table') }} stt_table
where not exists (
    select 1 from {{ ref('int_rvdkk_min_false') }} min_false
    where stt_table.kh_tv = min_false.kh_tv
      and stt_table.stt  >= min_false.min_value
)
