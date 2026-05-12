{{
  config(
    materialized = 'table',
    alias        = 'report_bao_cao_sua_xoa_du_lieu_changed_source'
  )
}} 

select 
	a.*,
	d.payment_date,
	g.payment_date as payment_date_2,
	b2.crm_id,
	b2.booking,
	b2.old_data,
	b2.new_data,
	b2.stag_date_changed,
	b2.user_changed,
	case
		when a.res_id is null then rb."name"
		else a.thuong_hieu_1
	end thuong_hieu,
	case
		when a.res_id is null then mrc."name"
		else a.chi_nhanh_1
	end chi_nhanh
from {{ ref('int_bcsxdl_mcsc_tns') }} a 
	left join (select * from {{ ref('stg_bcscdl_1st_payment_transfer') }} where rnk = 1) d on d.crm_id = a.res_id and d.brand_etl = a.brand_etl
	full join {{ ref('stg_bcsxdl_view_ks_crm_lead_trans_field_tns') }} b2 on b2.crm_id = a.res_id and b2.brand_etl = a.brand_etl 
	left join (select * from {{ ref('stg_bcscdl_1st_payment_transfer') }} where rnk = 1) g on g.crm_id = b2.crm_id and g.brand_etl = b2.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'crm_lead') }} cl2 on cl2.id = b2.crm_id and b2.brand_etl = cl2.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'res_brand') }} rb on rb.id = cl2.brand_id and cl2.brand_etl = rb.brand_etl
	left join {{ source('bao_cao_sua_xoa_du_lieu', 'm_res_company') }} mrc on mrc.id = cl2.company_id and mrc.brand_etl = cl2.brand_etl
order by a.date_changed desc