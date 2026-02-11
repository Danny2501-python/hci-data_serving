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
        b.ngay_tao, -- Giữ nguyên kiểu timestamp/date từ nguồn
        b.nguon_moi as nguon,
        b.chi_nhanh_new as chi_nhanh,
        b.nhom_dv,
        b.his_service_type,
        b.work_email_normalized as work_email, -- Dùng email đã chuẩn hóa
        b.ten_khach,
        b.ma_kh,
        b.ma_booking,
        b.surgery_type,
        b.tinh,
        b.chinhanhphanquyen,
        b.ten_dv,
        b.ma_phieu,
        
        -- Thông tin nhân viên Sale (Lateral Join logic)
        upper(tts."name") as nhan_vien_tts,
        tts.group_name as nhom_nv,
        tts.team_id
        
    from base b
    -- Gọi Macro để join lấy Sale Team theo NGAY_TAO
    left join lateral (
        select 
            sc."name",
            sc."group_name",
            sc."group" as team_id,
            sc.work_email 
        from {{ source('kangnam_source', 'table_team_sale_trans_field') }} sc
        where sc.work_email = b.work_email_normalized
          and date(sc.expiration_date) >= date(b.ngay_tao)
        order by sc.expiration_date asc
        limit 1
    ) tts on true
    
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
        b.ngay_tao as date_nt, -- Đổi tên cột cho khớp logic cũ
        b.nguon, -- Lưu ý: Logic gốc dùng 'nguon', Lead dùng 'nguon_moi'. Base có cả 2? Kiểm tra lại base.
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
    -- Gọi Macro (Logic giống Lead: theo NGAY_TAO)
    left join lateral (
        select sc."name", sc."group_name", sc."group" as team_id 
        from {{ source('kangnam_source', 'table_team_sale_trans_field') }} sc
        where sc.work_email = b.work_email_normalized
          and date(sc.expiration_date) >= date(b.ngay_tao)
        order by sc.expiration_date asc limit 1
    ) tts on true

    where b.phong_ban_nguoi_tao is not null
      and tts.group_name is not null -- Điều kiện lọc thêm của Booking
),

-- 3. HEN LICH (HL)
hen_lich as (
    select 
        b.page,
        'ad' as ad_id,
        'HL' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        date(b.ngay_hl) as date_hl, -- Cột ngày chính
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
    -- Gọi Macro theo NGAY_HL
    left join lateral (
        select sc."name", sc."group_name", sc."group" as team_id 
        from {{ source('kangnam_source', 'table_team_sale_trans_field') }} sc
        where sc.work_email = b.work_email_normalized
          and date(sc.expiration_date) >= date(b.ngay_hl)
        order by sc.expiration_date asc limit 1
    ) tts on true

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
        date(b.ngay_den_cua) as date_dc, -- Cột ngày chính
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
    -- Gọi Macro theo NGAY_DEN_CUA
    left join lateral (
        select sc."name", sc."group_name", sc."group" as team_id 
        from {{ source('kangnam_source', 'table_team_sale_trans_field') }} sc
        where sc.work_email = b.work_email_normalized
          and date(sc.expiration_date) >= date(b.ngay_den_cua)
        order by sc.expiration_date asc limit 1
    ) tts on true

    where b.phong_ban_nguoi_tao is not null
      and tts.group_name is not null
),

-- 5. THANH CONG (TC)
thanh_cong as (
    select 
        b.page, -- Lưu ý: Function gốc lấy mfpk.tên (đã có trong base.page)
        'ad' as ad_id,
        'TC' as bang,
        cast(b.ticket_id as text) as ticket_id,
        b.sdt,
        date(b.ngay_dc) as date, -- Function gốc lấy ngay_dc làm ngày chính?? (Cần check lại logic gốc, ở đây làm theo gốc)
        b.nguon_moi as nguon, -- TC dùng nguon_moi
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
    -- Gọi Macro theo NGAY_DEN_CUA (Logic gốc join theo ngay_den_cua)
    left join lateral (
        select sc."name", sc."group_name", sc."group" as team_id 
        from {{ source('kangnam_source', 'table_team_sale_trans_field') }} sc
        where sc.work_email = b.work_email_normalized
          and date(sc.expiration_date) >= date(b.ngay_den_cua)
        order by sc.expiration_date asc limit 1
    ) tts on true

    where b.loai_ban_ghi = 2 
      and b.tong_tien > 0
      and b.phong_ban_nguoi_tao is not null
      and tts.group_name is not null
),

-- 6. DOANH SO (DS)
doanh_so as (
    select 
        'page' as page, -- Hardcode 'page' theo logic gốc
        'ad' as ad_id,
        'DS' as bang,
        cast(b.ticket_id as text) as ticket_id,
        
        -- QUAN TRỌNG: Logic gốc nhét doanh_so vào cột sdt. Ta làm y hệt.
        cast(b.doanh_so as text) as sdt, 
        
        b.ngay_tt as date_nt, -- Các bảng trên dùng date_nt/date_hl... ta thống nhất 1 tên alias ở đây là date_nt để union
        b.nguon_moi as nguon,
        b.chinhanh as chi_nhanh, -- Gốc dùng column chinhanh (cũ)
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
    -- Gọi Macro theo NGAY_TT
    left join lateral (
        select sc."name", sc."group_name", sc."group" as team_id 
        from {{ source('kangnam_source', 'table_team_sale_trans_field') }} sc
        where sc.work_email = b.work_email_normalized
          and date(sc.expiration_date) >= date(b.ngay_tt)
        order by sc.expiration_date asc limit 1
    ) tts on true

    where b.loai_ban_ghi = 2
      and tts.group_name is not null
)

-- FINAL SELECT: UNION ALL
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
