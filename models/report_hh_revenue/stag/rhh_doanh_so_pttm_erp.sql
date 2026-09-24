-- Doanh số PTTM (Phẫu thuật thẩm mỹ) lấy từ ERP (stag_payment_transfer) —
-- BỔ SUNG cho rhh_doanh_so_pttm (lấy từ EHC/HIS, phòng khám 94).
-- Dòng "Phẫu thuật thẩm mỹ" của báo cáo = rhh_doanh_so_pttm + model này.
--
-- CÁCH NHẬN DIỆN: cohort theo KHÁCH HÀNG, không theo nhóm DV.
-- Lấy mọi thanh toán bên ERP của những khách ĐÃ CÓ HỒ SƠ PHÒNG 94 bên EHC
-- (ehc_tb_patientrecord.roomid_kb = 94), ghép 2 hệ qua SỐ ĐIỆN THOẠI
-- (crm_lead.phone = ehc_tb_patientrecord.patientphone).
--
-- Vì sao không lọc theo nhóm DV: khoản ERP của khách PTTM mang nhóm DV
-- 'PTTM HÀM MẶT' — cùng nhóm với cả mảng hàm mặt/nha khoa của VP Thương hiệu.
-- Lọc theo nhóm DV sẽ ôm nhầm toàn bộ mảng đó (T7/2026: 95.500.000 thay vì
-- 18.000.000; T8/2026: 791.000.000 thay vì 0). Cohort theo khách mới đúng.
--
-- ĐÃ VERIFY khớp tuyệt đối số người dùng đưa:
--   T7/2026 = 18.000.000 — đúng 1 phiếu 'PDC/2026/3799' (28/07, ĐOÀN NGỌC
--     CHIỀU, 'Tháo nẹp vít 2 bên gò má', nguồn Hợp tác_Bệnh viện HH Hà Nội).
--     Khách này mã EHC 22005663, roomid/roomid_kb = 94 liên tục từ 2022.
--     Tháng 7 bên EHC bà có 2 dòng 3.000.000 và -3.000.000 triệt tiêu nên EHC
--     ghi 0 — toàn bộ 18 triệu nằm bên ERP.
--   T8/2026 = 0 — không khách phòng 94 nào phát sinh bên ERP.
--
-- Phạm vi pháp nhân giống rhh_doanh_so_lgbt_erp_*:
--   - brand_etl = 4 (Hồng Hà, mọi company): mọi nguồn, chỉ loại 'cbnv'.
--   - brand_etl = 1 AND company_id = 54 (VP Thương hiệu Kangnam): whitelist
--     3 nhóm nguồn (hợp tác doanh nghiệp / hợp tác bệnh viện / CTV khách hàng).
--
-- KHÔNG chồng lấn với rhh_doanh_so_lgbt_erp_vpth: model đó đã loại nhóm DV
-- 'PTTM HÀM MẶT', còn khoản PTTM bên ERP thì đúng là nhóm 'PTTM HÀM MẶT'.
--
-- view_stag_products PHẢI join kèm brand_etl — product_id không unique toàn
-- cục (vd 32266 = 'nhổ răng khôn' ở brand 1 nhưng 'Săng mổ' ở brand 4).
--
-- spt.payment ÂM là bình thường (cả PDC lẫn phiếu thu/hoàn) — KHÔNG đảo dấu.

with khach_phong_94 as (
    select distinct btrim(pr.patientphone) as phone
    from {{ source('rhh_base', 'ehc_tb_patientrecord') }} pr
    where pr.roomid_kb = 94
      and coalesce(btrim(pr.patientphone), '') <> ''
)

select
    date_trunc('month', spt.payment_date)::date as thang,
    spt.payment_date as ngay,
    spt.ma_phieu,
    spt.payment_type,
    spt.ma_phieu ilike 'CUST.IN%' as la_coc,
    case when spt.brand_etl = 4 then 'BV Hồng Hà'
         else 'VP Thương hiệu Kangnam' end as phap_nhan,
    p.product_category,
    p.product,
    p.product_group,
    l.contact_name as khachhang,
    l.phone,
    l.name as booking,
    s.source,
    s.category_source,
    spt.brand_etl,
    spt.company_id,
    spt.crm_id,
    spt.product_id,
    spt.payment as sotien
from {{ source('rhh_base', 'stag_payment_transfer') }} spt
join {{ source('rhh_base', 'view_stag_products') }} p
       on p.product_id = spt.product_id
      and p.brand_etl  = spt.brand_etl
left join {{ source('rhh_base', 'crm_lead') }} l
       on l.id        = spt.crm_id
      and l.brand_etl = spt.brand_etl
left join {{ source('rhh_base', 'stag_sources') }} s
       on s.old_id = l.source_id
join khach_phong_94 k
       on k.phone = btrim(l.phone)
-- Giới hạn nhóm DV 'PTTM HÀM MẶT' để KHÔNG chồng lấn với
-- rhh_doanh_so_lgbt_erp_vpth (model đó lấy mọi nhóm DV TRỪ nhóm này).
-- Không có điều kiện này thì 2 model trùng nhau 2 dòng nhóm 'PHỤ THU KHÁC':
-- 'Phí xét nghiệm - Phụ thu' 500.000 (01/10/2025, HUỲNH ANH KHOA) và
-- 'Phụ thu thuê phòng đại phẫu 1h' 20.000.000 (07/02/2026, CRONIN MATTHEW
-- TYNAN). T7/T8-2026 không đổi khi thêm điều kiện; T2/2026 giảm 90tr -> 70tr.
where p.product_category = 'PTTM HÀM MẶT'
  and (
        (
            spt.brand_etl = 4
        and coalesce(s.source, '') not ilike '%cbnv%'
        )
     or (
            spt.brand_etl  = 1
        and spt.company_id = 54
        and (
                s.source ilike '%hợp tác doanh nghiệp%'
             or s.source ilike '%hợp tác%bệnh viện%'
             or s.source ilike '%ctv khách hàng%'
            )
        )
      )
