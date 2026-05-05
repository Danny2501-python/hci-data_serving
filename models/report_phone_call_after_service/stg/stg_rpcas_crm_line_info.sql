-- Bảng stg_rpcas_crm_line_info: bảng thông tin booking line
SELECT 
    vseu2.employee                                  as ng_tao,
    cl2.stage                                       as tt_line_ps,
    cl2.id                                          as id_line_ps,
    sp2.product                                     as dv,
    smhcs.product_id                                as ma_dv,
    vseu.employee                                   as tu_van1,
    vseu.department                                 as pb_tu_van1,
    cl.create_by_department                        as pb_ng_tao,
    ss."source"                                     as nguon_book_ps,
    cl.code_customer                                as ma_kh, 
    cl.id                                           as id_crm_lead_ps, 
    vseu2.department_id                             as ma_pb_tu_van1, 
    cl."name"                                       as booking_ps , 
    date(cl2.create_date + '07:00:00'::interval)    as ngay_tao, 
    cs."name"                                       as tt_book , 
    spt.ma_phieu                                    as ma_phieu, 
    spt.payment_date                                as payment_date, 
    spt.payment                                     as doanh_so, 
    spt.company_id                                  as company_id , 
    spt.id                                          as id
FROM
    {{ source('phone_call_after_service','crm_lead')}} cl
    left join {{ source('phone_call_after_service','crm_stage')}} cs on cl.stage_id = cs.id and cl.brand_etl = cs.brand_etl
    left join {{ source('phone_call_after_service','stag_sources')}} ss on cl.source_id = ss.old_id and cl.brand_etl = ss.brand_etl
    left join {{ source('phone_call_after_service','crm_line')}} cl2 on cl.id = cl2.crm_id and cl.brand_etl = cl2.brand_etl
    left join {{ source('phone_call_after_service','view_stag_employees_user')}} vseu on cl.create_by = vseu.user_id and cl.brand_etl = vseu.brand_etl
    left join {{ source('phone_call_after_service','view_stag_employees_user')}} vseu2 on cl2.consultants_1 = vseu2.user_id and cl2.brand_etl = vseu2.brand_etl
    left join {{ source('phone_call_after_service','sh_medical_health_center_service')}} smhcs on smhcs.id = cl2.service_id and smhcs.brand_etl = cl2.brand_etl
    left join {{ source('phone_call_after_service','view_stag_products')}} sp2 on sp2.product_id = smhcs.product_id and sp2.brand_etl = smhcs.brand_etl
    left join {{ source('phone_call_after_service','stag_payment_transfer')}} spt on spt.crm_id = cl.id and spt.clineid = cl2.id and spt.brand_etl = cl.brand_etl and spt.brand_etl = cl2.brand_etl
WHERE cl2.stage <> 'cancel' and cl.type_crm_id = 2
    
