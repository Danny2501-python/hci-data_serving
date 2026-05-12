select 
	mcsc.id,
	mcsc.old_value_char, 	
	case  		
		when cl.brand_id = 3 then ss12.category_source_code
		else ss11.category_source_code
	end as category_source_name_old, 	
	mcsc.new_value_char, 	
	case  		
		when cl.brand_id = 3 then ss22.category_source_code
		else ss21.category_source_code
	end as category_source_name_new, 	
	mcsc.date_changed,
	mcsc.res_id,
	mcsc.write_uid, 	
	se."name" as name_changed,
	se.employee_code ,
	se.department,
	cl."name",
	cl."type", 	
	cl.contact_name,
	cl.phone , 	
	cl.create_on + interval '7 hours' as create_date_book, 	
	rb."name" as thuong_hieu_1,
	mrc."name" as chi_nhanh_1,
	case
		when b.total_payment is null then 0
		else b.total_payment
	end as total_payment,
	case
		when csb.stage = 'cancel' then 'Hủy'
		when csb.stage = 'done' then 'Hoàn thành'
		when csb.stage = 'wait' then 'Chờ'
		else csb.stage
	end as stage,
	ct."name" as approver,
	case
		when csb.stage = 'wait' then null
		else csb.write_date + interval '7 hours'
	end as approval_time,
	mcsc.status_bk,
	mcsc.brand_etl,
	replace(csb.note, E'\n', '') as note
from {{ ref('stg_bcsxdl_stag_mail_message_changed_source') }} mcsc 
	left join lateral (
		select * 
		from {{ ref('stg_bcsxdl_hr_employee_trans_field') }} se 
		where mcsc.write_uid = se.user_id 
		and date(se.expiration_date) >= date(mcsc.write_date) 
		and se.brand_etl = mcsc.brand_etl order by expiration_date limit 1 ) se on true
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'crm_lead') }} cl on cl.id = mcsc.res_id and cl.brand_etl = mcsc.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'stag_sources') }} ss11 on ss11.old_id = mcsc.old_value_integer
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'stag_sources') }} ss12 on ss12.old_id = ss11.id_pr 
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'stag_sources') }} ss21 on ss21.old_id = mcsc.new_value_integer
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'stag_sources') }} ss22 on ss22.old_id = ss21.id_pr
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb on rb.id = cl.brand_id and cl.brand_etl = rb.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc on mrc.id = cl.company_id and cl.brand_etl = mrc.brand_etl
	left join {{ ref('stg_bcscdl_summerized_payment') }} b on b.crm_id = mcsc.res_id and b.brand_etl = mcsc.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'change_source_base') }} csb on csb.crm_id = cl.id and csb.brand_etl = cl.brand_etl
	left join lateral(
		select * 
		from {{ ref('stg_bcsxdl_hr_employee_trans_field') }} se 
		where csb.write_uid = se.user_id 
		and date(se.expiration_date) >= date(csb.write_date) 
		and se.brand_etl = csb.brand_etl order by expiration_date limit 1 ) ct on true