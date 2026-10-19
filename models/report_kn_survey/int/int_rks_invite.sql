-- int_rks_invite: thông tin lời mời khảo sát (kn_survey_cms_invite), 1 dòng / invite
-- Thời gian lưu UTC trong Odoo -> cộng 7h về giờ VN
SELECT
    i.id                                                as invite_id,
    i.code                                              as ma_khao_sat,
    i.brand_etl,

    -- Khách hàng
    i.partner_id,
    rp.name                                             as ten_kh,
    rp.code_customer                                    as ma_kh,
    rp.phone                                            as sdt,
    i.booking_id,
    cl.name                                             as booking,
    ss.source                                           as nguon,
    ss.category_source                                  as nhom_nguon,
    us.name                                             as nguon_moi,
    ccs.name                                            as nhom_nguon_moi,

    -- Phiếu
    i.ticket_type,
    case i.ticket_type
        when 'walkin'     then 'Phiếu khám'
        when 'evaluation' then 'Phiếu tái khám'
        else i.ticket_type
    end                                                 as loai_phieu,
    i.name                                              as ma_phieu,
    i.res_model,
    i.res_id,
    i.institution_id,
    smhc.company_name                                   as benh_vien,
    i.company_id,
    mrc.name                                            as chi_nhanh,
    sv.service_ids,
    sv.dich_vu,
    sv.nhom_dich_vu,
    i.doctor_id,
    vseu.employee_code                                  as ma_bac_si,
    vseu.employee                                       as bac_si,
    i.service_date + '07:00:00'::interval               as ngay_thuc_hien,

    -- Gửi khảo sát
    i.touchpoint_id,
    tp.name                                             as diem_cham,
    i.channel,
    case i.channel
        when 'zalo' then 'Zalo'
        when 'app'  then 'Kangnam Care App'
        when 'sms'  then 'SMS'
        else i.channel
    end                                                 as kenh_gui,
    i.send_date + '07:00:00'::interval                  as thoi_gian_gui,
    i.deadline + '07:00:00'::interval                   as han_khao_sat,
    i.survey_url                                        as link_khao_sat,
    i.sms_id,

    -- Kết quả
    i.open_count                                        as so_lan_mo_link,
    i.first_open_date + '07:00:00'::interval            as thoi_gian_mo_link,
    i.survey_done_date + '07:00:00'::interval           as thoi_gian_submit,
    i.case_id                                           as case_khieu_nai,
    cc.code                                             as ma_case,
    i.state                                             as trang_thai,
    i.classification                                    as phan_loai,
    i.alert_keywords,
    i.note                                              as ghi_chu,
    i.error_message,

    i.create_date + '07:00:00'::interval                as ngay_tao
FROM {{ source('kn_survey', 'kn_survey_cms_invite') }} i
    left join {{ source('kn_survey', 'res_partner') }} rp on rp.id = i.partner_id and rp.brand_etl = i.brand_etl
    left join {{ source('kn_survey', 'crm_lead') }} cl on cl.id = i.booking_id and cl.brand_etl = i.brand_etl and cl.type_crm_id <> 1
    left join {{ source('kn_survey', 'stag_sources') }} ss on ss.old_id = cl.source_id
    left join {{ source('kn_survey', 'utm_source') }} us on us.id = cl.new_source_id and us.brand_etl = cl.brand_etl
    left join {{ source('kn_survey', 'crm_category_source') }} ccs on ccs.id = us.category_id and ccs.brand_etl = us.brand_etl
    left join {{ source('kn_survey', 'sh_medical_health_center') }} smhc on smhc.id = i.institution_id and smhc.brand_etl = i.brand_etl
    left join {{ source('kn_survey', 'm_res_company') }} mrc on mrc.id = i.company_id and mrc.brand_etl = i.brand_etl
    left join {{ source('kn_survey', 'sh_medical_physician') }} smp on smp.id = i.doctor_id and smp.brand_etl = i.brand_etl
    left join {{ source('kn_survey', 'view_stag_employees_user') }} vseu on vseu.user_id = smp.sh_user_id and vseu.brand_etl = smp.brand_etl
    left join {{ source('kn_survey', 'kn_survey_cms_touchpoint') }} tp on tp.id = i.touchpoint_id and tp.brand_etl = i.brand_etl
    left join {{ source('kn_survey', 'crm_case') }} cc on cc.id = i.case_id and cc.brand_etl = i.brand_etl
    left join {{ ref('stg_rks_invite_service') }} sv on sv.invite_id = i.id and sv.brand_etl = i.brand_etl
