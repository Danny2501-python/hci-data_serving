{{ config(materialized='table') }}

with base as (
    select * from {{ ref('int_sales_kangnam_clean') }}
),

-- 1. LEAD TOTAL
lead_total as (
    select 
        b.page,
        'ad' as ad_id,
        'Lead_total' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        b.ngay_tao, 
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
        b.ma_phieu,
        
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.team_id
        
    from base b
    -- Dùng Macro: base alias='b', cột ngày='ngay_tao'
    {{ get_sale_team('b', 'ngay_tao') }}
    
    where b.loai_ban_ghi = 1
      and b.phong_ban_nguoi_tao is not null
      and b.trang_thai in ('Tiềm năng', 'Tham khảo', 'Đặt lịch')
),

-- 2. BOOKING (BK)
booking as (
    select 
        b.page,
        'ad' as ad_id,
        'BK' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        b.ngay_tao as date_nt,
        b.nguon,
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
        b.ma_phieu,
        
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.team_id
        
    from base b
    -- Dùng Macro: base alias='b', cột ngày='ngay_tao'
    {{ get_sale_team('b', 'ngay_tao') }}

    where b.phong_ban_nguoi_tao is not null
      and tts.group_name is not null
),

-- 3. HEN LICH (HL)
hen_lich as (
    select 
        b.page,
        'ad' as ad_id,
        'HL' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        date(b.ngay_hl) as date_hl,
        b.nguon,
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
        b.ma_phieu,
        
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.team_id
        
    from base b
    -- Dùng Macro: base alias='b', cột ngày='ngay_hl'
    {{ get_sale_team('b', 'ngay_hl') }}

    where b.phong_ban_nguoi_tao is not null
      and tts.group_name is not null
),

-- 4. DEN CUA (DC)
den_cua as (
    select 
        b.page,
        'ad' as ad_id,
        'DC' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        date(b.ngay_den_cua) as date_dc,
        b.nguon,
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
        b.ma_phieu,
        
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.team_id
        
    from base b
    -- Dùng Macro: base alias='b', cột ngày='ngay_den_cua'
    {{ get_sale_team('b', 'ngay_den_cua') }}

    where b.phong_ban_nguoi_tao is not null
      and tts.group_name is not null
),

-- 5. THANH CONG (TC)
thanh_cong as (
    select 
        b.page,
        'ad' as ad_id,
        'TC' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        date(b.ngay_dc) as date, -- Logic gốc dùng ngay_dc (hoặc ngay_den_cua)
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
        b.ma_phieu,
        
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.team_id
        
    from base b
    -- Dùng Macro: base alias='b', cột ngày='ngay_den_cua' (Lưu ý: Logic gốc join với ngay_den_cua)
    {{ get_sale_team('b', 'ngay_den_cua') }}

    where b.loai_ban_ghi = 2 
      and b.tong_tien > 0
      and b.phong_ban_nguoi_tao is not null
      and tts.group_name is not null
),

-- 6. DOANH SO (DS)
doanh_so as (
    select 
        'page' as page,
        'ad' as ad_id,
        'DS' as bang,
        cast(b.ticket_id as text) as ticket_id,
        cast(b.doanh_so as text) as sdt, -- Ép kiểu doanh_so -> sdt
        
        date(b.ngay_tt) as date_nt,
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
        b.ma_phieu,
        
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.team_id
        
    from base b
    -- Dùng Macro: base alias='b', cột ngày='ngay_tt'
    {{ get_sale_team('b', 'ngay_tt') }}

    where b.loai_ban_ghi = 2
      and tts.group_name is not null
)

-- FINAL SELECT
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
