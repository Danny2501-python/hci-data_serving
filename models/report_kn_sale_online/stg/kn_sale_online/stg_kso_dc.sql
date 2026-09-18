select  'page' as page,
        'ad' ad_id,
        'DC' as bang,
        stks.ticket_id,
        stks.sdt,
        upper(tts.name) as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.group team_id,
        date(stks.ngay_den_cua) date,
        stks.nguon_moi nguon ,
        stks.chinhanh as chi_nhanh,
        stks.nhom_dv,
        stks.his_service_type,
        stks.work_email,
        stks.ten_khach,
        stks.ma_kh,
        stks.ma_booking,
        stks.surgery_type,
        stks.tinh,
        stks.chinhanhphanquyen chinhanhphanquyen,
        stks.ten_dv,
        stks.vao_so ma_phieu,
        stks.vk
from (select * from {{ref('stg_kso_map')}}  stks 
where loai_ban_ghi= 2 
and (reason_cancel_booking not in ('tao_booking_bh') 
 or  reason_cancel_booking is null)
) stks
	left join lateral(
		select sc."name",sc."group_name" ,sc.group, sc.work_email 
		from table_team_sale_trans_field sc 
		where sc.work_email = stks.work_email 
		and date(sc.expiration_date) >= date(stks.ngay_den_cua) 
		order by expiration_date limit 1) tts on true
