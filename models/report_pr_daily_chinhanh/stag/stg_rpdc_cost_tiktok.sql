{{
  config(materialized = 'ephemeral')
}}
select
'cost' type_report,
0 chinhanhphanquyen,
'chinhanh' chinhanh,
'note' note,
"date created"::date,
'ten_khach' ten_khach,
'ma_kh' ma_kh,
'ma_booking' ma_booking,
'phan_loai_dv' phan_loai_dv,
'nhom_dv'  nhom_dv,
case 
 	when "tên chiến dịch" ilike ('%nieng%') or "tên chiến dịch" ilike ('%nr%') then 'Niềng răng'
 	when "tên chiến dịch" ilike ('%su%') then 'Răng sứ'
 	when "tên chiến dịch" ilike ('%implant%') then 'Implant'
 	when "tên chiến dịch" ilike ('%ham%') then 'Hàm mặt'
 	else 'DV còn lại' 
 	end  nhom_dv_dc,
'dv_trong_tam'  dv_trong_tam,
0 loai_ban_ghi,
'MD - Tiktok' nguon,
'Tiktok' source_new,
'sdt' sdt,
"chi phí" cost,
'Online' ctg_source_new
from {{ source('rpdc', 'tiktok_raw_ad') }}