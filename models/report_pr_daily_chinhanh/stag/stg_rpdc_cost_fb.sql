{{
  config(materialized = 'ephemeral')
}}
select
'cost' type_report,
0 chinhanhphanquyen,
'chinhanh' chinhanh,
'note' note,
date,
'ten_khach' ten_khach,
'ma_kh' ma_kh,
'ma_booking' ma_booking,
'phan_loai_dv' phan_loai_dv,
'nhom_dv'  nhom_dv,
case 
 	when cfi.ad_campaign_name ilike ('%nieng%') or cfi.ad_campaign_name ilike ('%nr%') then 'Niềng răng'
 	when cfi.ad_campaign_name ilike ('%su%') then 'Răng sứ'
 	when cfi.ad_campaign_name ilike ('%implant%') then 'Implant'
 	when cfi.ad_campaign_name ilike ('%ham%') then 'Hàm mặt'
 	else 'DV còn lại'
 end  nhom_dv_dc,
'dv_trong_tam'  dv_trong_tam,
0 loai_ban_ghi,
'MD - Facebook' nguon,
'Facebook' source_new,
'sdt' sdt,
spend,
'Online' ctg_source_new
from {{ source('rpdc', 'cs_facebook_insight') }} cfi
where brand_etl =3