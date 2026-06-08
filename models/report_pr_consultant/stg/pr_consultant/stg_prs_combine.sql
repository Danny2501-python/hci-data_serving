select 
        cl.arrival_date,
        cl.booking_date,
        cl.expire_date,
        spt.payment_date,
        cl.thuonghieu,
        cl.lead_company,
        mrc.name company,
        cl.crm_id,
        cl.create_by_department,
        cl.customer_come,
        cl.booking,
        dc.result reason_out_sold,
        dc1.result reason_cancel_booking,
        cl.amount_paid,
        cl.type_crm_id,
        cl.type_data_partner,
        cl.code_customer,
        cl.contact_name,
        cs.name crm_stage,
        cl2.clineid,
        cl.source_id,
        ss.source,
        ss.category_source_ss category_source,
        sp.default_code,
        ad.nhom_dv_trongtam dd_trong_tam,
        sp.product_category,
        cl2.product_id,
        sp.product,
        cl2.stage,
        cl2.reason_line_cancel,
        cl2.cancel_user,
        cic.id cic,
        se.employee,
        se.job,
        	case 
				when cic.role = 'recept' then 1
				when cic.role = 'doctor' then 2
				when  cic.role = 'support' then 3
			end as "role",
        cic.user_id,
        spt.id_phieu,
        spt.ma_phieu,
        spt.payment_method,
        spt.quantity,
        spt.payment,
        spt.payment_type,
        spt.company_id,
        se1.company_id "cty_cancel",
        se.company_id "cty_tv",
        ss.org_source 
from {{ref('prs_crm_lead')}} cl
left join {{ref('prs_cline')}} cl2 on cl.crm_id = cl2.crm_id
left join (select  * from  {{ref('prs_convert_case_when')}} 
where  column_name = 'reason_out_sold') dc 
on dc.value_case_when = cl.reason_out_sold 
left join (select  * from  {{ref('prs_convert_case_when')}}
where  column_name = 'reason_cancel_booking') dc1
on dc1.value_case_when = cl.reason_cancel_booking 
left join {{ref('prs_source')}} ss on ss.old_id = cl.source_id
left join  (select * from {{source('prs_raw_data','view_stag_products')}} where brand_etl=3) sp 
on sp.product_id= cl2.product_id
left join {{ref('prs_payment')}} spt on spt.crm_id = cl.crm_id
 and spt.clineid = cl2.clineid and spt.product_id = cl2.product_id
left join (select * 
from  {{source('prs_raw_data','crm_information_consultant')}} 
where brand_etl =3) cic 
on cic.crm_line_id = cl2.clineid
left join (select * from {{source('prs_raw_data','view_stag_employees_user')}} where brand_etl =3) se 
on se.user_id = cic.user_id
left join (select * from {{source('prs_raw_data','view_stag_employees_user')}} where brand_etl =3) se1
on se.user_id = cl2.cancel_user
left join (select * from {{source('prs_raw_data','crm_stage')}} where brand_etl =3) cs on cs.id = cl.stage_id
left join (select * from {{source('prs_raw_data','m_res_company')}} where brand_etl =3 ) mrc 
on mrc.id = cl.lead_company
left join m_nhom_dv_adnet_paris ad on ad.default_code = sp.default_code
 
