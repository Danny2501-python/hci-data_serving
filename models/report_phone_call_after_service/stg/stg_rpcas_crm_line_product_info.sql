-- Bảng stg_rpcas_crm_line_info: bảng thông tin booking line
select 
    vseu."employee"                                     as ng_tao, 
    clp.stage_line_product                              as tt_line_ps, 
    clp.id                                              as id_line_ps, 
    sp2.product                                         as dv, 
    clp.product_id                                      as ma_dv, 
    vseu2."employee"                                    as tu_van1, 
    vseu2."department"                                  as pb_tu_van1, 
    cl.create_by_department                             as pb_ng_tao, 
    us."source"                                         as nguon_book_ps, 
    cl.code_customer                                    as ma_kh, 
    cl.id                                               as id_crm_lead_ps, 
    vseu2.department_id                                 as ma_pb_tu_van1, 
    cl."name"                                           as booking_ps , 
    date(clp.create_date + '07:00:00'::interval)        as ngay_tao, 
    cs."name"                                           as tt_book , 
    spt.ma_phieu                                        as ma_phieu, 
    spt.payment_date                                    as payment_date, 
    spt.payment                                         as doanh_so, 
    spt.company_id                                      as company_id , 
    spt.id                                              as id
from {{ source('phone_call_after_service','crm_lead')}} cl 
    left join {{ source('phone_call_after_service','crm_stage')}} cs on cs.id = cl.stage_id and cs.brand_etl = cl.brand_etl
    left join {{ source('phone_call_after_service','stag_sources')}} us on us.old_id = cl.source_id and us.brand_id = cl.brand_etl
    left join {{ source('phone_call_after_service','crm_line_product')}} clp on clp.booking_id = cl.id and clp.brand_etl = cl.brand_etl
    left join {{ source('phone_call_after_service','view_stag_employees_user')}} vseu on cl.create_by = vseu.user_id and vseu.brand_etl = cl.brand_etl
    left join {{ source('phone_call_after_service','view_stag_employees_user')}} vseu2 on vseu2.user_id = clp.consultants_1 and vseu2.brand_etl = clp.brand_etl
    left join {{ source('phone_call_after_service','view_stag_products')}} sp2 on sp2.product_id = clp.product_id and sp2.brand_etl = clp.brand_etl
    left join {{ source('phone_call_after_service','stag_payment_transfer')}} spt 
        on spt.crm_id = cl.id 
        and spt.clineid = clp.id 
        and spt.brand_etl = cl.brand_etl 
        and spt.brand_etl = clp.brand_etl
where clp.stage_line_product <> 'cancel' and cl.type_crm_id = 2 

