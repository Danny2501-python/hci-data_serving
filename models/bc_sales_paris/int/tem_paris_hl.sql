
select
    'ad' as ad_id,
    'HL' as bang,
    ctk.ticket_id,
    null as requester_id,
    ctk.nv,
    ctk.email,
    date(ctk.ngay_hl) as date,
    ctk.nguon,
    ctk.chi_nhanh,
    ctk.nhom_dv,
    ctk.ten_khach,
    ctk.ma_booking,
    ctk.phong_ban_nguoi_tao as phong_ban,
    ctk.sdt,
    cast(null as text) as metric
from {{ ref('cte_tongquan_khachhang') }} ctk
left join lateral (
    select 	b.brand_id
    from 	{{ source('paris_raw', 'res_company_trans_field') }} b
    where
        b.id = ctk.chinhanhphanquyen
        and date(b.expiration_date)>= date(ctk.ngay_hl)
    limit 1 ) chi_nhanh 
on true
where
    ctk.loai_ban_ghi = 2
    and chi_nhanh.brand_id = 3
    and ctk.nhom_dv <> 'Sản Phẩm'
    and ctk.nhom_dv is not null
