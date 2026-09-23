-- Bảng test: vật thể hoá model ephemeral rhh_ehc_payment_service ra một bảng
-- để tiện truy vấn/đối soát bằng tay, KÈM 4 cột nguồn bên ERP map theo
-- id_booking. Mọi logic doanh số vẫn nằm nguyên ở int/rhh_ehc_payment_service.
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
-- Tên cột khớp rhh_doanh_so_combine: old_source_name / new_source_name.
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

rel as (
    select u.old_source_id, u.source_id
    from {{ source('rhh_base', 'utm_source_old_source_rel') }} u
    where u.source_server = 'hh'
      and u.brand_etl = 4
),

us as (
    select id, name
    from {{ source('rhh_base', 'utm_source') }}
    where brand_etl = 4
)

select
    e.*,
    ld.erp_source_id_old,
    us_old.name  as old_source_name,
    rel.source_id as erp_source_id_new,
    us_new.name  as new_source_name
from {{ ref('rhh_ehc_payment_service') }} e
left join lead_dedup ld on ld.id_booking = e.id_booking
left join rel            on rel.old_source_id = ld.erp_source_id_old
left join us us_old      on us_old.id = ld.erp_source_id_old
left join us us_new      on us_new.id = rel.source_id
