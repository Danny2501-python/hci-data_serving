-- Bảng stg_rpcas_data_tk: Data tái khám
select 
    sme.id as id_tk, 
    sme."name" as tk, 
    sme.walkin as id_pk,
    smarw."name" as pk, 
    rp."name" as ten_kh, 
    rp.code_customer as ma_kh, 
    sme.evaluation_start_date + '7hours' as time_bat_dau, 
    sme.evaluation_end_date + '7hours' as time_ket_thuc, 
    date(sme.evaluation_start_date + '7hours') as ngay_tk, 
    sme.state , 
    smes."name" as loai_tk, 
    'Đúng lịch' as dung_sai_lich 
from {{ source('phone_call_after_service','sh_medical_evaluation')}} sme 
    left join {{ source('phone_call_after_service','sh_medical_appointment_register_walkin')}} smarw on smarw.id = sme.walkin and smarw.brand_etl = sme.brand_etl 
    left join {{ source('phone_call_after_service','sh_medical_patient')}} smp on smp.id = sme.patient and smp.brand_etl = sme.brand_etl 
    left join {{ source('phone_call_after_service','res_partner')}} rp on rp.id = smp.partner_id and rp.brand_etl = smp.brand_etl 
    left join {{ source('phone_call_after_service','sh_evaluation_services_type_rel')}} sestr on sestr.evaluation_id = sme.id and sestr.brand_etl = sme.brand_etl 
    left join {{ source('phone_call_after_service','sh_medical_evaluation_services')}} smes on smes.id = sestr.evaluation_services_id and smes.brand_etl = sestr.brand_etl 
where 
    sme.state = 'Completed' 
    and exists (
        select 1 
        from {{ source('phone_call_after_service','crm_phone_call')}} cpc 
        where 
            sme.walkin = cpc.medical_id and sme.brand_etl = cpc.brand_etl 
            and date(cpc.booking_date + '7hours') = date(sme.evaluation_start_date + '7hours')
    )