
select
    text(cl.ticket_id) as ticket_id,
    stks.sdt,
    upper(stks.nhan_vien) as nv,
    stks.ngay_tao,
    stks.nhom_dv,
    stks.chinhanhphanquyen,
    stks.loai_ban_ghi,
    stks.trang_thai,
    stks.chi_nhanh,
    stks.nguon_moi as nguon,
    stks.ngay_hl,
    stks.ngay_dc,
    stks.ngay_den_cua,
    stks.vao_so,
    stks.doanh_so,
    stks.ngay_tt,
    stks.ten_khach,
    stks.ma_booking,
    stks.phong_ban_nguoi_tao,
    rp.email
from {{ source('paris_raw', 'stag_tongquan_khachhang_sm') }} stks
left join {{ source('paris_raw', 'crm_lead') }} cl on cl.id = stks.id
left join {{ source('paris_raw', 'res_users') }} ru on ru.id = cl.create_by
left join {{ source('paris_raw', 'res_partner') }} rp on rp.id = ru.partner_id
left join {{ source('paris_raw', 'table_team_sale_paris') }} tts on tts.work_email = rp.email
where cl.active is true
