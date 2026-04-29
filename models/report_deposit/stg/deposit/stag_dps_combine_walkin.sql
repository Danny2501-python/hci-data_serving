--Merge để lấy thông tin liên quan bảng phiếu khám
select 
        smarw."name" as pk, 
        smarw.date as ngay_kham,
        case when smarw.service_date_start is null then smarw.date
        else smarw.service_date_start
        end as ngay_lam_dv, 
        smarw.booking_id,
        smarw.state as trang_thai,
        cl."name" as bk, 
        smarw.id as walkin_id,
        sp.product as sp,
        sp.product_id ,
        sol.crm_line_id,
        cl2.number_used,
        sp.product_category ,
        cl2.stage , 
        cl2.total as tien_phai_thu,
        cl2.total_received as tien_da_thu,
        cl.code_customer as ma_kh,
        cl2.consultants_1,
        cl.partner_id,
        cl2.brand_etl brand_etl_cl2,
        smarw.brand_etl  brand_etl_smarw,
        cl2.id clineid
from {{ ref('dps_smarw') }} smarw
left join {{ref('dps_crm_lead')}} cl on smarw.booking_id = cl.id and smarw.brand_etl=cl.brand_etl
left join {{source ('raw_data','sh_walkin_service_rel')}} swsr  on swsr.walkin_id = smarw.id and smarw.brand_etl = swsr.brand_etl
left join  {{source ('raw_data','sh_medical_health_center_service')}} smhcs on smhcs.id = swsr.service_id and smhcs.brand_etl = swsr.brand_etl
left join  {{source ('raw_data','sale_order_line')}} sol on sol.order_id = smarw.sale_order_id and sol.brand_etl = smarw.brand_etl
left join {{ref('dps_cline')}} cl2 on cl2.id = sol.crm_line_id and cl2.brand_etl = sol.brand_etl 
left join {{source ('raw_data','view_stag_products')}}  sp on sp.product_id = cl2.product_id and sp.brand_etl = cl2.brand_etl
where smarw.state ='Completed'