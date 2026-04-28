select 
        cl.arrival_date as ngay_dc,
        cl.contact_name as ten_khach,
        cl2.stage, 
        cl.code_customer  as "Mã Khách",
        cl."name" as "Booking",
        cl.phone as dienthoai,
        cl2.id as "Line_id",
        tv1.employee  as "Nhân Viên",
       -- sp.product as "Tên DV",
        cl2.total_received as tien_con,
        sp.product as "Tên DV", ---
        sp.product_category as "Nhóm Dịch Vụ",
        ---cl2.total_received as tien_con, --
        cl2.total/1000 as "Doanh Thu Kì Vọng",
        (cl2.total- cl2.total_received) as cong_no,
        case 
	        when cl2.consultants_1 is null then cic.user_id
	        else cl2.consultants_1
        end  as tu_van1_id,
        case
            when tv2.employee  is null 
            then tv3.employee 
            else tv2.employee 
	    end as tu_van1,
        case when tv2.department  is null then tv3.department else tv2.department end as pb_tu_van1,
        case when tv2.department_id  is null then tv3.department_id else tv2.department_id end as pb_tu_van1_id,
        cl2.create_date as ngay_tao_line,
        cl.id as id_lead,
        sp.default_code ,
        cl.brand_etl brand_etl_cl,
        cl2.brand_etl brand_etl_cl2,
        cl.source_id    
from (select * from {{ref('dps_crm_lead')}} where type_crm_id=2) cl 
left join (select * from {{ref('dps_cline')}} where number_used =0) cl2 on cl2.crm_id = cl.id and cl2.brand_etl = cl.brand_etl
left join {{ref('dps_tv')}} tv1 on tv1.user_id = cl.create_by and tv1.brand_etl = cl.brand_etl
left join {{ref('dps_tv')}} tv2 on tv2.user_id = cl2.consultants_1 and tv2.brand_etl = cl2.brand_etl
left join {{ref('dps_cic')}} cic on cic.crm_line_id  = cl2.id and cic.brand_etl =cl2.brand_etl
left join {{ref('dps_tv')}} tv3 on tv3.user_id = cic.user_id and cic.brand_etl = tv3.brand_etl
left join {{source('raw_data','view_stag_products')}} sp on sp.product_id = cl2.product_id and sp.brand_etl = cl2.brand_etl

