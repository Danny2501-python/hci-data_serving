
select 
    'page' as page,
    'ad' as ad_id,
    'DS' as bang,
    cast(b.ticket_id as text) as ticket_id,
    cast(b.doanh_so as text) as sdt,
    upper(tts."name") as nhan_vien_tts,
    tts.group_name as nhom_nv,
    tts."group" as team_id,
    date(b.ngay_tt) as date,
    b.nguon_moi as nguon,
    b.chinhanh as chi_nhanh,
    b.nhom_dv,
    b.his_service_type,
    b.work_email_normalized as work_email,
    b.ten_khach,
    b.ma_kh,
    b.ma_booking,
    b.surgery_type,
    b.tinh,
    b.chinhanhphanquyen,
    b.ten_dv,
    b.ma_phieu
from {{ ref('cte_stag_tongquan_khachhang_sm') }} b
{{ get_sale_team('b', 'ngay_tt') }}
where b.loai_ban_ghi = 2
    and tts.group_name is not null
