{{
  config(materialized = 'ephemeral')
}}
select
'cost' type_report,
0 chinhanhphanquyen,
'chinhanh' chinhanh,
'note' note,
date::date,
'ten_khach' ten_khach,
'ma_kh' ma_kh,
'ma_booking' ma_booking,
'phan_loai_dv' phan_loai_dv,
'nhom_dv' nhom_dv,
case 
	when campaign ilike ('%niềng%') or  campaign ilike ('%nieng%')then  'Niềng răng'
	when campaign ilike ('%implant%') then 'Implant'
	when campaign ilike ('%sứ%') or campaign ilike ('%su%') then 'Răng sứ'
	when campaign ilike ('%thuong%') or campaign ilike ('%thương%') then 'Thương hiệu'
	when campaign ilike ('%hàm%') or campaign ilike ('ham') then 'Hàm mặt'
  else 'DV còn lại'
	end  nhom_dv_dc,
'dv_trong_tam'  dv_trong_tam,
0 loai_ban_ghi,
'MD - Search' nguon,
'Google_Ads' source_new,
'sdt' sdt,
cost,
'Online' ctg_source_new
from {{ source('rpdc', 'google_ad_paris') }}