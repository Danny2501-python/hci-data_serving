select  stks.page,
        'ad' ad_id,
        'DS' as bang,
        stks.ticket_id,
        stks.sdt,
        upper(tts.name) as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.group team_id,
        date(stks.ngay_tt) date,
        stks.nguon_moi nguon ,
        stks.chi_nhanh_new as chi_nhanh,
        stks.nhom_dv,
        sstks.his_service_type,
        stks.work_email,
        stks.ten_khach,
        stks.ma_kh,
        stks.ma_booking,
        stks.surgery_type,
        stks.tinh,
        stks.company_id chinhanhphanquyen,
        stks.ten_dv,
        stks.vao_so ma_phieu
from ({{ref('stg_kso_map')}}  stks 
where loai_ban_ghi= 2 and tong_tien > 0)
	left join lateral(
		select sc."name",sc."group_name" ,sc.group, sc.work_email 
		from table_team_sale_trans_field sc 
		where sc.work_email = stks.work_email 
		and date(sc.expiration_date) >= date(stks.ngay_tt) 
		order by expiration_date limit 1) tts on true
