-- Tương đương bảng tạm data2 trong func_data_vong_doi_khach_hang
-- Thêm: tong_da_nhan_book, book_tc, ma_kh_new

select
    data1.*,
    sum(data1.doanh_so) over (partition by data1.id_lead)                           as tong_da_nhan_book,
    case when sum(data1.doanh_so) over (partition by data1.id_lead) > 0
         then 'Book thành công'
    end                                                                             as book_tc,
    case when data1.ma_kh is null then data1.phone else data1.ma_kh end             as ma_kh_new
from {{ ref('int_rvdkk_data1') }} data1
