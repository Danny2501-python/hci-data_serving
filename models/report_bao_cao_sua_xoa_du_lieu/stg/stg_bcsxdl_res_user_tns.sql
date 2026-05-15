select
		ru.id,
		rp."name",
		rp.code_customer,
		hd."name" as department,
		mrc."name" as company,
		rb."name" as brand,
		ru.brand_etl
	from
		{{ source('bao_cao_sua_xoa_du_lieu', 'res_users') }} ru
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'res_partner') }} rp on
		rp.id = ru.partner_id and rp.brand_etl = ru.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'hr_employee') }} he on
		he.user_id = ru.id and he.brand_etl = ru.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'hr_department') }} hd on
		he.department_id = hd.id and he.brand_etl = hd.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc on
		mrc.id = ru.company_id and mrc.brand_etl = ru.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb on
		rb.id = mrc.brand_id and rb.brand_etl = mrc.brand_etl 