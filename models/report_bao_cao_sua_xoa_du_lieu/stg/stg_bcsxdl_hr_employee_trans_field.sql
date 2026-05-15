select
	hetf.*,
	hd."name" as department,
	mrc."name" as company,
	rb."name" as brand
from
	{{ source('bao_cao_sua_xoa_du_lieu', 'hr_employee_trans_field') }} hetf
left join {{ source('bao_cao_sua_xoa_du_lieu', 'hr_department') }} hd on
	hetf.department_id = hd.id and hetf.brand_etl = hd.brand_etl
left join {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc on
	mrc.id = hetf.company_id and hetf.brand_etl = mrc.brand_etl
left join {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb on
	rb.id = mrc.brand_id and hetf.brand_etl = rb.brand_etl
where
	hetf.user_id <> 0
	and hetf.user_id is not null