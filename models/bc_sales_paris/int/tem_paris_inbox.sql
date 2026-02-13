
select
    a.ad_id as ad_id,
    'Inbox' as bang,
    text(a.ticket) as ticket_id,
    text(a.khach_id) as requester_id,
    upper(tts.name) as nv,
    tts.work_email as email,
    a.ngay_tao_khach as date,
    a.nguon as nguon,
    chi_nhanh.name as chi_nhanh,
    ccfk.value_lable as nhom_dv,
    a.username as ten_khach, 
    null as ma_booking, 
    vseu.department as phong_ban,
    null as sdt,
    cast(null as text) as metric
from {{ ref('ranked_contacts') }} a
left join {{ ref('cs_service_category') }} x on 	x.id = a.khach_id
left join {{ source('paris_raw', 'cs_custom_fields_kh') }} ccfk on ccfk.value_id = x.extracted_value_not_null
left join {{ ref('cs_company') }} cc on text(cc.ticket_id) = text(a.ticket)
left join {{ source('paris_raw', 'cs_custom_fields') }} ccf2 on 	cc.extracted_value = ccf2.value_id
left join lateral (
    select 	b.name
    from {{ source('paris_raw', 'res_company_trans_field') }} b
    where 
        b.company_code = replace(left(ccf2.value_lable,
        position( ']' in ccf2.value_lable)-1), '[', '')
            and date(b.expiration_date)>= date(a.ngay_tao_khach)
        limit 1 ) chi_nhanh 
on true
left join {{ source('paris_raw', 'table_team_sale_paris') }} tts on tts.work_email = a.mail_nv
left join {{ source('paris_raw', 'view_stag_employees_user') }} vseu on vseu.work_email = a.mail_nv
left join {{ source('paris_raw', 'm_facebook_page_kangnam') }} mfpk on mfpk.id = a.page_fb
where 	a.rank = 1 
