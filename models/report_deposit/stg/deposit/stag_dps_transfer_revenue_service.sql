select 
        wk.pk,
        wk.ngay_kham,
        wk.ngay_lam_dv,
        wk.booking_id,
        wk.trang_thai,
        wk.bk,
        wk.walkin_id,
        wk.sp,
        wk.product_id,
        wk.crm_line_id,
        wk.number_used,
        wk.product_category,
        wk.stage,
        wk.tien_phai_thu,
        wk.tien_da_thu,
        wk.ma_kh,
        rp.name ten_kh,
        case
        when wk.consultants_1 is null then cic.user_id
        else wk.consultants_1
        end as tu_van1_id,
        case
        when wk.consultants_1 is null then tv3.employee
        else tv2.employee
        end as tu_van1,
        case
        when tv2.department is null then tv3.department
        else tv2.department
        end as pb_tu_van1,
         case
        when tv2.department_id is null then tv3.department_id
        else tv2.department_id
        end as pb_tu_van1_id,
        wk.brand_etl_smarw brand_etl,
        row_number() over(partition by wk.crm_line_id order by wk.ngay_lam_dv asc) rnk
from {{ref('stag_dps_combine_walkin')}} wk 
left join {{source('raw_data','res_partner')}} rp on rp.id = wk.partner_id
left join {{ref('dps_tv')}} tv2 on tv2.user_id = wk.consultants_1
and wk.brand_etl_cl2 = tv2.brand_etl
left join  (select * from {{source('raw_data','crm_information_consultant')}}  cic where "role" = 'recept'  ) cic 
on cic.crm_line_id = wk.clineid and cic.brand_etl = wk.brand_etl_cl2
left join {{ref('dps_tv')}} tv3
 on tv3.user_id = cic.user_id and tv3.brand_etl = cic.brand_etl


