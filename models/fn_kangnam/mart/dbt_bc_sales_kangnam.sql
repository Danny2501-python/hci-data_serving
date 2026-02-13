{{ config(materialized='table') }}

with base as (
    select * from {{ ref('cte_stag_tongquan_khachhang_sm') }}
),

lead_total as (
    select 
        b.page,
        'ad' as ad_id,
        'Lead_total' as bang,
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
    from base b
    {{ get_sale_team('b', 'ngay_tao') }}
    where b.loai_ban_ghi = 1
      and b.phong_ban_nguoi_tao is not null
      and b.trang_thai in ('Tiềm năng', 'Tham khảo', 'Đặt lịch')
),

booking as (
    select 
        --b.page,
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
    from base b
    {{ get_sale_team('b', 'ngay_tao') }}
    where b.phong_ban_nguoi_tao is not null
      and b.loai_ban_ghi = 2
      and b.trang_thai <> 'Hủy'
      and tts.group_name is not null
),

hen_lich as (
    select 
        b.page,
        'ad' as ad_id,
        'HL' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts."group" as team_id,
        date(b.ngay_hl) as date,
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
    from base b
    {{ get_sale_team('b', 'ngay_hl') }}
    where b.phong_ban_nguoi_tao is not null
      and b.loai_ban_ghi = 2
      and b.trang_thai <> 'Hủy'
      and tts.group_name is not null
),

den_cua as (
    select 
        b.page,
        'ad' as ad_id,
        'DC' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts."group" as team_id,
        date(b.ngay_den_cua) as date,
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
    from base b
    {{ get_sale_team('b', 'ngay_den_cua') }}
    where b.phong_ban_nguoi_tao is not null
      and b.loai_ban_ghi = 2
      and b.trang_thai <> 'Hủy'
      and tts.group_name is not null
),

thanh_cong as (
    select 
        b.page,
        'ad' as ad_id,
        'TC' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts."group" as team_id,
        date(b.ngay_dc) as date,
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
    from base b
    {{ get_sale_team('b', 'ngay_den_cua') }}
    where b.loai_ban_ghi = 2 
      and b.tong_tien > 0
      and b.phong_ban_nguoi_tao is not null
      and tts.group_name is not null
),

doanh_so as (
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
    from base b
    {{ get_sale_team('b', 'ngay_tt') }}
    where b.loai_ban_ghi = 2
      and tts.group_name is not null
)

select * from lead_total
union all
select * from booking
union all
select * from hen_lich
union all
select * from den_cua
union all
select * from thanh_cong
union all 
select * from doanh_so
