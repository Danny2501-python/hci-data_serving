-- Output của report_hh_revenue: gộp doanh thu dịch vụ (int/rhh_ehc_payment_service_base),
-- nhà thuốc (stag/rhh_doanh_so_nha_thuoc) và target (ggs_target_company brand_id = 4),
-- phân biệt bằng cột nguon_du_lieu, KÈM 4 cột nguồn bên ERP map theo id_booking
-- và tên phòng. Logic doanh thu dịch vụ nằm ở int/rhh_ehc_payment_service_base.
--
-- Bảng map dùng m_utm_source_old_new_map (brand_etl = 4, 38 dòng / 38
-- old_source_id duy nhất nên join không nhân dòng), khớp 100% với
-- utm_source_old_source_rel (525->687, 293->706, 287->708...).
--
-- old_source_name VẪN lấy từ utm_source (brand_etl = 4) chứ KHÔNG lấy cột cùng
-- tên trong bảng map: bảng map chỉ chứa 38 nguồn có ánh xạ sang hệ mới, còn
-- utm_source brand 4 có đủ 209 nguồn. Dùng bảng map làm nguồn tên cũ sẽ tụt độ
-- phủ T8/2026 từ 1.542 xuống 259 dòng, mất hẳn 'K - Cho thuê phòng Mổ'
-- (12,6 tỷ), 'K - CTV nội bộ', 'K_CTV Bác sĩ/đối tác cá nhân',
-- 'ML - KH giới thiệu KH'. coalesce() để phòng trường hợp ngược lại.
--
-- VẪN join utm_source (brand_etl = 4) theo new_source_id để lấy new_source_name
-- — hiện NULL 100% vì brand 4 chỉ có id 1..657, không có dòng nào trong dải
-- 686-712. Chính cột new_source_name TRONG m_utm_source_old_new_map cũng NULL
-- toàn bộ cho brand 4 (brand 1/3/8 thì đầy đủ), nên đây là thiếu từ gốc chứ
-- không phải cách join. Khi ERP đồng bộ danh mục nguồn mới cho Hồng Hà, chạy
-- lại model là tên tự hiện.
--
-- Chuỗi map: id_booking = crm_lead.name (brand_etl = 4)
--   -> crm_lead.source_id LÀ ID CŨ (đã verify: 8.617 lead brand 4 khớp
--      utm_source_old_source_rel.old_source_id, 0 lead khớp .source_id)
--   -> utm_source_old_source_rel (source_server = 'hh') đổi sang id mới
--   -> utm_source lấy tên, giải theo ĐÚNG BRAND của dòng rel (brand_etl = 4).
--
-- utm_source.id KHÔNG duy nhất toàn cục — mỗi brand có dải id riêng (giống
-- product_id). Giải id theo brand_etl = 8 (VDE) như bản đầu cho ra tên LỆCH
-- ĐÚNG 1 VỊ TRÍ (Facebook->Instagram, Tiktok->Youtube...) vì mượn nhầm danh
-- mục của brand khác. Danh mục nguồn mới của Hồng Hà CHƯA được đồng bộ sang
-- utm_source (brand 4 có max id 657, 0 dòng is_new_source, 0/38 id mới giải
-- được) nên erp_source_new_name hiện luôn NULL — đúng hơn là điền tên sai.
-- Kiểm chứng: kn/pr/vde giải trong chính brand mình đạt 60/60, 32/32, 31/31.
-- Riêng id cũ thì brand 4 và brand 8 trùng tên 100% (10.936/10.936 dòng 2026).
--
-- Hai chỗ phải chống nhân dòng:
--   - crm_lead.name trùng 1.975 giá trị (1.033 trong đó có source_id khác
--     nhau) -> distinct on, giữ lead ghi sau cùng.
--   - source_id (mới) -> nhiều old_source_id (vd 700 có 3 id cũ), nhưng chiều
--     ngược lại old_source_id là DUY NHẤT (38/38 dòng) nên join theo
--     old_source_id không nhân dòng.
--
-- Tên cột old_source_name / new_source_name được report_hh_thv_ds_kh
-- (int/rhtdk_hh) dùng lại nguyên tên.
--
-- Độ phủ T8/2026: ~19% booking map được; phần còn lại là [TPM]Thuê phòng mổ và
-- [CTV]Cộng tác viên — tên bác sĩ/cá nhân không tồn tại trong utm_source.
-- erp_source_old_name tương ứng với source_ehc (khớp 91%), KHÔNG phải nhóm
-- dm_hoahongnguoigioithieu_nguoigioithieuname.

with lead_dedup as (
    select distinct on (l.name)
           l.name as id_booking,
           l.source_id as erp_source_id_old
    from {{ source('rhh_base', 'crm_lead') }} l
    where l.brand_etl = 4
      and coalesce(btrim(l.name), '') <> ''
    order by l.name, l.write_date desc nulls last, l.id desc
),

map_nguon as (
    select old_source_id, old_source_name, new_source_id
    from {{ source('rhh_base', 'm_utm_source_old_new_map') }}
    where brand_etl = 4
),

us as (
    select id, name
    from {{ source('rhh_base', 'utm_source') }}
    where brand_etl = 4
),

phong as (
    select roomid, roomname
    from {{ source('rhh_base', 'ehc_tb_room') }}
),

vien_phi as (
    select 'Dịch vụ'::text as nguon_du_lieu, e.*, null::text as bac_si, null::text as loai_phau_thuat
    from {{ ref('rhh_ehc_payment_service_base') }} e
),

nha_thuoc as (
    select
        'Nhà thuốc'::text as nguon_du_lieu,
        nt.source_ehc,
        etp.id_booking,
        nt.ngay::date               as invoicedate,
        nt.sotienphieu,
        nt.ghichu                   as invoiceremark,
        'Thu tiền nhà thuốc'::text  as loaiphieu,
        nt.sophieu,
        nt.patientphone,
        coalesce(nt.patientname, nt.khachhang) as patientname,
        nt.patientcode,
        nt.patientrecordid,
        null::integer               as invoiceid,
        nt.dm_hoahongnguoigioithieu_nguoigioithieuname,
        null::integer               as roomid,
        etp.roomid_kb,
        'DT trừ cọc trong tháng'::text as pl,
        null::text                  as bac_si,
        null::text                  as loai_phau_thuat
    from {{ ref('rhh_doanh_so_nha_thuoc') }} nt
    left join {{ source('rhh_base', 'ehc_tb_patientrecord') }} etp
           on etp.patientrecordid = nt.patientrecordid
),

target as (
    select
        'Target'::text              as nguon_du_lieu,
        null::text                  as source_ehc,
        null::text                  as id_booking,
        t.time                      as invoicedate,
        t.target                    as sotienphieu,
        t.brand                     as invoiceremark,
        'Chỉ tiêu'::text            as loaiphieu,
        t.id_target_company::text   as sophieu,
        null::text                  as patientphone,
        t.company                   as patientname,
        null::text                  as patientcode,
        null::integer               as patientrecordid,
        null::integer               as invoiceid,
        null::text                  as dm_hoahongnguoigioithieu_nguoigioithieuname,
        null::integer               as roomid,
        null::integer               as roomid_kb,
        null::text                  as pl,
        null::text                  as bac_si,
        null::text                  as loai_phau_thuat
    from {{ source('rhh_base', 'ggs_target_company') }} t
    where t.brand_id = 4
      and t.active
),

-- Khoản TRỪ (sotienphieu âm), logic port từ report_tableau_doanh_so_tap_doan_HCI
-- int_rtds_hongha — xem comment đầu 2 model stag. bac_si chỉ có ở dòng
-- 'Lương bác sĩ' (phẫu thuật viên chính), các khối khác NULL. loai_phau_thuat
-- (Đại phẫu / Tiểu phẫu) cũng chỉ có ở dòng 'Lương bác sĩ'.
tui_nguc_mong as (
    select 'Túi ngực/mông'::text as nguon_du_lieu, t.*, null::text as bac_si, null::text as loai_phau_thuat
    from {{ ref('rhh_doanh_so_tui_nguc_mong') }} t
),

luong_bac_si as (
    select 'Lương bác sĩ'::text as nguon_du_lieu, l.*
    from {{ ref('rhh_doanh_so_luong_bac_si') }} l
),

gop as (
    select * from vien_phi
    union all
    select * from nha_thuoc
    union all
    select * from target
    union all
    select * from tui_nguc_mong
    union all
    select * from luong_bac_si
)

select
    e.*,
    ld.erp_source_id_old,
    coalesce(us_old.name, m.old_source_name) as old_source_name,
    m.new_source_id as erp_source_id_new,
    us_new.name  as new_source_name,
    p1.roomname  as roomname,
    p2.roomname  as roomname_kb
from gop e
left join lead_dedup ld on ld.id_booking = e.id_booking
left join map_nguon m    on m.old_source_id = ld.erp_source_id_old
left join us us_old      on us_old.id = ld.erp_source_id_old
left join us us_new      on us_new.id = m.new_source_id
left join phong p1       on p1.roomid = e.roomid
left join phong p2       on p2.roomid = e.roomid_kb
