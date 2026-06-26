{{ config(alias='func_data_vong_doi_khach_hang') }}

-- Tương đương bảng tạm data_up trong func_data_vong_doi_khach_hang
-- Gộp:
--   1. Toàn bộ DV thành công (đã có final_result) từ data_dv_tc
--   2. Các dòng dv_tc = null từ data3 (chưa có DV thành công)

select * from {{ ref('int_rvdkk_data_dv_tc') }}

union all

select
    *,
    null as kh_tv,
    null as check_tv_rk1,
    null as check_rnk_ago,
    null::integer as stt,
    null as final_result
from {{ ref('int_rvdkk_data3') }}
where dv_tc is null
