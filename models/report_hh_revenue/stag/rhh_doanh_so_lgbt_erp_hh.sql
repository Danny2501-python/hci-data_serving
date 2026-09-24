-- Doanh số LGBT (ERP) — pháp nhân BỆNH VIỆN HỒNG HÀ (brand_etl = 4).
-- Tách từ rhh_doanh_so_lgbt_erp; model kia giờ chỉ union 2 model con.
-- Model sinh đôi: rhh_doanh_so_lgbt_erp_vpth (VP Thương hiệu Kangnam).
--
-- Nguồn: stag_payment_transfer (phiếu thu bên ERP/CRM) — KHÁC với
-- rhh_doanh_so_lgbt lấy từ EHC/HIS (phòng khám 276).
--
-- Bộ lọc:
--   - brand_etl = 4, MỌI company (24 BV Hồng Hà, 32 BV Hồng Hà HCM, ...).
--     Company 32 có 1 dòng 2.000.000 trước 2026; năm 2026 chỉ company 24 phát
--     sinh, toàn bộ qua nguồn 'MD - Facebook'.
--   - Nhận diện LGBT THEO nhóm DV (product_category ilike '%lgbt%'). Khác hẳn
--     nhánh VP Thương hiệu — bên đó lọc ngược (trừ 'PTTM HÀM MẶT') vì pháp
--     nhân đó chỉ chạy 2 mảng LGBT + hàm mặt, còn Hồng Hà làm đủ mọi chuyên
--     khoa nên phải lọc xuôi.
--   - Lấy mọi nguồn, chỉ loại nguồn chứa 'cbnv' (đồng bộ với
--     rhh_doanh_so_san_khoa / rhh_doanh_so_ung_buou). Hiện chưa có dòng LGBT
--     nào dính CBNV ở bất kỳ brand nào — giữ để phòng dữ liệu tương lai.
--
-- 3 join đều 1-1, đã verify không fan-out:
--   - view_stag_products : (product_id, brand_etl). BẮT BUỘC kèm brand_etl —
--     product_id KHÔNG unique toàn cục, vd product_id 32266 là 'Phẫu thuật nhổ
--     răng khôn' ở brand 1 nhưng là 'Săng mổ' ở brand 4, 'Kem Ủ Trắng Body' ở
--     brand 3. Bỏ brand_etl khỏi join sẽ nhân 5 lần số dòng và ra sản phẩm sai.
--   - crm_lead      : spt.crm_id = crm_lead.id, kèm brand_etl.
--   - stag_sources  : crm_lead.source_id = stag_sources.old_id (old_id unique).
--
-- CẢNH BÁO ĐẾM TRÙNG với rhh_doanh_so_lgbt (EHC): khoản cọc CUST.IN xuất hiện
-- ở CẢ 2 nguồn. Vd 'CUST.IN/2026/0022' 2.500.000 (NGUYỄN HOÀNG HẢI, 30/08/2026)
-- vừa ở đây vừa ở rhh_doanh_so_lgbt với pl = 'Cọc trong tháng', room 276.
-- Khi cộng 2 nguồn phải trừ cọc một bên — dùng cột `la_coc` bên dưới.
--
-- spt.payment ÂM là bình thường (cả PDC lẫn phiếu thu/hoàn) — KHÔNG đảo dấu.
--
-- Số 2026: T1 14.000.000 · T3 1.000.000 · T4 5.000.000 · T7 2.000.000 ·
-- T8 2.500.000. Các tháng khác không phát sinh.

select
    date_trunc('month', spt.payment_date)::date as thang,
    spt.payment_date as ngay,
    spt.ma_phieu,
    spt.payment_type,
    spt.ma_phieu ilike 'CUST.IN%' as la_coc,
    'BV Hồng Hà'::text as phap_nhan,
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
where spt.brand_etl = 4
  and p.product_category ilike '%lgbt%'
  and coalesce(s.source, '') not ilike '%cbnv%'
