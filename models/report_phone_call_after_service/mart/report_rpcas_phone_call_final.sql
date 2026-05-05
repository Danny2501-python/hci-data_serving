{{
  config(
    materialized = 'table',
    alias        = 'report_rpcas_phone_call_final'
  )
}}

select
	cpc.id 																					as id_phonecall,
	rp."name" 																				as ten_kh,
	cpc.phone 																				as sdt,
	cpc.code_customer 																		as ma_kh,
	cpc.call_date + '7hours' 																as ngay_goi,
	cpc.booking_date + '7hours' 															as ngay_hl,
	cpc.state 																				as trang_thai,
	cpc.brand_id,
	cpc.company_id,
	mrc."name" 																				as chi_nhanh,
	rb."name" 																				as thuong_hieu,
	cpc.crm_id 																				as id_book,
	cl."name" 																				as booking,
	so."name" 																				as so,
	cpc.order_id,
	cpc.medical_id 																			as id_pk,
	smarw."name" 																			as pk,
	cpc.care_type 																			as don_vi_cham_soc,
	cpc.type_pc 																			as loai,
	sp.product_id,
	sp.product,
	sp.product_category,
	sp.his_service_type,
	cpc."desc" 																				as mo_ta,
	cpc.note 																				as ghi_chu,
	cpch.ticket_id,
	cca.id 																					as id_cs_call,
	cpch.call_id,
	cca.caller ,
	cca.start_time 																			as time_bat_dau,
	cca.end_time 																			as time_ket_thuc,
	date(cca.start_time)																	as ngay_goi_thuc_te,
	cca.start_time 																			as ngay_goi_thuc_te_fulltime,
	cca.talk_time 																			as time_goi,
	extract(EPOCH from cca.talk_time::interval)												as giay_goi,
	case
		when cca.caller = cpc.phone then true
		else false
	end 																					as check_db,
	case
		when extract(EPOCH from cca.talk_time::interval) >>= 15 then 'Kết nối'
		else 'Không kết nối'
	end 																					as loai_ket_noi,
	cca.call_status,
	cca.agent_id 																			as id_ng_goi,
	caa.username 																			as ng_goi,
	case
		when dt.dung_sai_lich is null then 'Sai lịch'
		else dt.dung_sai_lich
	end 																					as dung_sai_lich,
	ce.id 																					as id_calendar,
	ce.start_datetime + '7hours' 															as henlich_calendar,
	cpc.type_crm_id,
	he.id 																					as id_ng_goi_erp,
	he."name" 																				as ten_ng_goi_erp,
	he.department_id																		as id_pb_ng_goi_erp,
	he.department																			as pb_ng_goi_erp,
	he.employee_code ,
	ps.id_line_ps,
	ps.booking_ps 																			as booking_ps,
	ps.id_crm_lead_ps,
	ps.ngay_tao 																			as ngay_tao_line_ps,
	ps.doanh_so 																			as payment_ps,
	ps.payment_date 																		as ngay_tt_ps,
	ps.id 																					as id_phieu_ps,
	ps.ma_phieu 																			as ma_phieu_ps,
	ps.dv 																					as dv_ps
from
	{{ source('phone_call_after_service','crm_phone_call')}} cpc
left join {{source('phone_call_after_service','res_partner')}} rp on
	rp.id = cpc.partner_id and rp.brand_etl = cpc.brand_etl 
left join {{source('phone_call_after_service','m_res_company')}} mrc on
	mrc.id = cpc.company_id and mrc.brand_etl = cpc.brand_etl
left join res_brand rb on
	rb.id = mrc.brand_id and rb.brand_etl = mrc.brand_etl
left join {{source('phone_call_after_service','crm_lead')}} cl on
	cl.id = cpc.crm_id and cl.brand_etl = cpc.brand_etl
left join {{source('phone_call_after_service','sale_order')}} so on
	so.id = cpc.order_id and so.brand_etl = cpc.brand_etl
left join {{source('phone_call_after_service','sh_medical_appointment_register_walkin')}} smarw on
	smarw.id = cpc.medical_id and smarw.brand_etl = cpc.brand_etl
left join {{source('phone_call_after_service','sh_walkin_service_rel')}} swsr on
	swsr.walkin_id = smarw.id and swsr.brand_etl = smarw.brand_etl
left join {{source('phone_call_after_service','sh_medical_health_center_service')}} smhcs on
	smhcs.id = swsr.service_id and smhcs.brand_etl = swsr.brand_etl
left join {{source('phone_call_after_service','view_stag_products')}} sp on
	sp.product_id = smhcs.product_id and sp.brand_etl = smhcs.brand_etl
left join {{ref('stg_rpcas_phone_call_history')}} cpch on
	cpch.id_phonecall = cpc.id and cpch.brand_etl = cpc.brand_etl
left join {{ source('phone_call_after_service','view_stag_employees_user')}} he on
	he.user_id = cpch.write_uid and he.brand_etl = cpch.brand_etl
-- left join hr_department hd on
-- 	hd.id = he.department_id
left join {{ source('phone_call_after_service','cs_call_api')}} cca on
	cca.ticket_id = cpch.ticket_id::numeric
left join {{ source('phone_call_after_service','cs_agents_api')}} caa on
	caa.agent_id = cca.agent_id
left join {{ ref('stg_rpcas_data_tk')}} dt on
	dt.id_pk = cpc.medical_id
	and date(cpc.booking_date + '7hours') = dt.ngay_tk
left join {{ source('phone_call_after_service','calendar_event')}} ce on
	ce.phonecall = cpc.id
left join {{ ref('int_rpcas_ps')}} ps on
	ps.ngay_tao = date(cpc.booking_date + '7hours')
	-- ngày tạo line = ngày đến tk, tbcc, liệu trình 			
	and ps.ma_kh = cpc.code_customer -- cùng mã khách hàng 
where cpc.type_pc in 
    ('Change','Change1','Change2','Change3','Change4','Change5','ReCheck','ReCheck1','ReCheck4','ReCheck5', 
    'ReCheck6','ReCheck7','ReCheck8','ReCheck11',
	'ReCheck9', --tái khám 
    'ReCheck10') -- liệu trình 
and date(cpc.call_date + '7hours') >>= '20250801' 