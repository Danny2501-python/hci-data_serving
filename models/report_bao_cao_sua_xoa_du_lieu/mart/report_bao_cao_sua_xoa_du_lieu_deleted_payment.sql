{{
  config(
    materialized = 'table',
    alias        = 'report_bao_cao_sua_xoa_du_lieu_deleted_payment'
  )
}}

select
	ldp.id as id_log,
	ldp.write_date + interval '7 hour' as deleted_date,
	case 
		when se."name" is null then ru."name"
		else se."name"
	end as deleted_username,
	case 
		when se."name" is null then ru.code_customer
		when se.employee_code is null then '0'
		else se.employee_code
	end as employee_code,
	case
		when se.department is null then ru.department
		else se.department
	end as department_user,
	case
		when se.company is null then ru.company
		else se.company
	end as company_user,
	case
		when se.brand is null then ru.brand
		else se.brand
	end as thuonghieu_user,
	cl."name" as book,
	cl.create_on as create_date_book, 
	pt."name" as line_service,
	case 
		when cl2.stage = 'new' then 'Được sử dụng'
		when cl2.stage = 'chotuvan' then 'Chờ tư vấn'
		when cl2.stage = 'processing' then 'Đang xử lý'
		when cl2.stage = 'done' then 'Kết thúc'
		when cl2.stage = 'waiting' then 'Chờ phê duyệt'
		when cl2.stage = 'cancel' then 'Hủy'
	end stage_line,
	ap."name" as invoice,
	csp.*
from
	{{ ref('stg_bcsxdl_logging_delete') }} ldp
    left join {{ source('bao_cao_sua_xoa_du_lieu', 'log_crm_sale_payment') }} lcsp 
        on ldp.res_id = lcsp.id and ldp.brand_etl = lcsp.brand_etl
    left join {{ source('bao_cao_sua_xoa_du_lieu', 'crm_lead') }} cl 
        on cl.id = lcsp.booking_id and cl.brand_etl = lcsp.brand_etl
    left join {{ source('bao_cao_sua_xoa_du_lieu', 'crm_line') }} cl2 
        on cl2.id = lcsp.crm_line_id and cl2.brand_etl = lcsp.brand_etl
    left join {{ source('bao_cao_sua_xoa_du_lieu', 'product_product') }} pp on
        pp.id = cl2.product_id and pp.brand_etl = cl2.brand_etl
    left join {{ source('bao_cao_sua_xoa_du_lieu', 'product_template') }} pt on
        pt.id = pp.product_tmpl_id and pt.brand_etl = pp.brand_etl
    left join {{ source('bao_cao_sua_xoa_du_lieu', 'account_payment') }} ap on
        ap.id = lcsp.account_payment_id and ap.brand_etl = lcsp.brand_etl
    left join {{ ref('stg_bcsxdl_auditlog_log') }} al 
        on al.res_id = ldp.res_id and al.brand_etl = ldp.brand_etl
    left join lateral(
	    select
		    *
	    from
		    {{ ref('stg_bcsxdl_hr_employee_trans_field') }} a
	    where
            a.user_id = al.user_id and a.brand_etl = al.brand_etl
            and date(a.expiration_date) >= date(al.create_date)
        order by
            expiration_date
        limit 1 ) se on true
left join {{ ref('stg_bcsxdl_res_user_tns') }} ru on ru.id = al.user_id and ru.brand_etl = al.brand_etl
left join {{ ref('stg_bcsxdl_csp') }} csp on csp.booking_id = lcsp.booking_id and csp.brand_etl = lcsp.brand_etl