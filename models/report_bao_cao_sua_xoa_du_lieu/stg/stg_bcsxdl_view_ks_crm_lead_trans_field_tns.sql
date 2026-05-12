select
		a.id as crm_id,
		booking,
		old_data,
		new_data,
		date_changed as stag_date_changed,
		rp."name" as user_changed,
		a.brand_etl
	from
		{{ source('bao_cao_sua_xoa_du_lieu', 'view_ks_crm_lead_trans_field') }} a
		left join {{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru on ru.id = a.write_uid and a.brand_etl = ru.brand_etl 
		left join {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp on	rp.id = ru.partner_id and rp.brand_etl = ru.brand_etl 
	where
		type_data = 'source'