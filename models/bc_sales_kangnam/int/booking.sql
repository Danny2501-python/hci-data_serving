
select 
    b.page,
    'ad' as ad_id,
    'BK' as bang,
    cast(b.ticket_id as text) as ticket_id,
    b.sdt,
    upper(tts."name") as nhan_vien_tts,
    tts.group_name as nhom_nv,
    tts."group" as team_id,
    date(b.ngay_tao) as date,
    b.nguon_moi as nguon, 
    b.chi_nhanh_new as chi_nhanh,
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
{{ get_sale_team('b', 'ngay_tao') }}
where b.phong_ban_nguoi_tao is not null
    and b.loai_ban_ghi = 2
    and b.trang_thai <> 'Hủy'
    and tts.group_name is not null
