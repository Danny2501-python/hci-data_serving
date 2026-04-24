with data_final as (
select  a.ngay_dc,
a.ten_khach,
a.stage,
a.ngay_thu_tien,
a."Mã Khách",
a."Booking",
a.dienthoai,
a."Line_id" line_id,
a."Tên DV",
a."Thương Hiệu",
a.thuonghieuphanquyen,
a.chinhanhphanquyen,
a."Nhân Viên",
a."Nhóm Dịch Vụ",
a.tien_con,
a."Tiền Cọc",
a."Doanh Thu Kì Vọng",
a."Kênh Truyền Thông",
a."Nhom_nguon",
a.cong_no,
a.nguon_book,
a.tu_van1_id,
a.tu_van1,
a.pb_tu_van1,
a.pb_tu_van1_id,
a.ngay_tao_line,
a.id_lead,
a.kenh,
a.category_channel,
a.default_code,
a.data_type,
a.nd_tt,
a.id_tt,
a.ma_phieu,
0 as thuonghieuphanquyenfinal, 
'pb_new.pb' as pb_tu_van1_sld, 
a."Chi nhánh" ,
row_number() over(partition by a.id_lead order by a.ngay_thu_tien desc) as rk_tt,
min(a.ngay_thu_tien) over(partition by a."Line_id", a.brand_etl) as min_tt,
dense_rank() over(partition by a."Line_id" order by a.ngay_thu_tien desc) as rk_line_tt,
a.brand_etl
 from {{ref('stag_dps_combine_payment_and_transfer')}}  a
/*left join lateral (select rctf.id, rctf."name" as pb 
from hr_department_trans_field rctf
where date(rctf.expiration_date) > a.ngay_tao_line
and rctf.id = a.pb_tu_van1_id order by rctf.expiration_date limit 1) pb_new
on true*/
)
select * from data_final 

---where min_tt >= '20230101'
