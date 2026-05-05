-- Bảng stg_rpcas_data_pk: Data phiếu khám
select
    smarw.id                                                as id_pk,
    smarw."name"                                            as pk,
    smarw.booking_id                                        as booking_id,
    cl."name"                                               as booking,
    date(smarw."date" + '7hours')                           as ngay_kham,
    smarw.info_diagnosis                                    as ly_do_kham,
    rp."name"                                               as ten_kh,
    rp.code_customer                                        as ma_kh,
    smarw.state                                             as state,
    'Đúng lịch'                                             as dung_sai_lich
from
    {{ source('phone_call_after_service','sh_medical_appointment_register_walkin')}} smarw
    left join {{ source('phone_call_after_service','crm_lead')}} cl 
        on cl.id = smarw.booking_id 
        and cl.brand_etl = smarw.brand_etl
    left join {{ source('phone_call_after_service','res_partner')}} rp 
        on rp.id = smarw.partner_id 
        and rp.brand_etl = smarw.brand_etl
where
    smarw.state = 'Completed'
    and exists (
        select
            1
        from
            {{ source('phone_call_after_service','crm_phone_call')}} cpc
        where
            smarw.booking_id = cpc.crm_id
            and smarw.brand_etl = cpc.brand_etl
            and date(cpc.booking_date + '7hours') = date(smarw."date" + '7hours')
    )