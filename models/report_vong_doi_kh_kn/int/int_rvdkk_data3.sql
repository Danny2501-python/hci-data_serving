-- Tương đương bảng tạm data3 trong func_data_vong_doi_khach_hang
-- nhánh 1: khách Book thành công → tính rnk, ngay_dc_truoc, min_dc
-- nhánh 2: khách chưa Book thành công → giữ null cho 3 cột window

-- nhánh 1
select
    data2.*,
    dense_rank() over (partition by data2.brand_id, data2.ma_kh_new order by data2.ngay_den_cua) as rnk,
    lag(data2.ngay_den_cua)  over (partition by data2.brand_id, data2.ma_kh_new order by data2.ngay_den_cua) as ngay_dc_truoc,
    min(data2.ngay_den_cua)  over (partition by data2.brand_id, data2.ma_kh_new)                  as min_dc
from {{ ref('int_rvdkk_data2') }} data2
where book_tc = 'Book thành công'

union all

-- nhánh 2
select
    data2.*,
    null as rnk,
    null as ngay_dc_truoc,
    null as min_dc
from {{ ref('int_rvdkk_data2') }} data2
where book_tc is null
