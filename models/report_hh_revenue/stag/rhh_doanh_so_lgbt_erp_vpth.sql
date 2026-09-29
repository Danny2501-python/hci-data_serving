-- Doanh số LGBT (ERP) — pháp nhân VĂN PHÒNG THƯƠNG HIỆU KANGNAM
-- (brand_etl = 1, company_id = 54).
-- Tách từ rhh_doanh_so_lgbt_erp; model kia giờ chỉ union 2 model con.
-- Model sinh đôi: rhh_doanh_so_lgbt_erp_hh (BV Hồng Hà).
--
-- CÁCH LỌC NGƯỢC so với nhánh Hồng Hà: pháp nhân này chỉ chạy 2 mảng là LGBT
-- và hàm mặt, nên lấy MỌI nhóm DV TRỪ 'PTTM HÀM MẶT' thay vì lọc theo nhóm DV
-- chứa 'LGBT'. Lý do: nhiều dịch vụ đi kèm ca LGBT nhưng nhóm DV gốc không ghi
-- LGBT, lọc xuôi sẽ sót:
--   'Xét nghiệm - Gói xét nghiệm thu ti' (PTTM KHÁC, product_id 10251)
--   'Tạo hình thu nhỏ đầu vú (núm vú)'   (PTTM NGỰC/MÔNG, product_id 4637)
--   'Phí xét nghiệm - Phụ thu'           (PHỤ THU KHÁC)
--   'Liệu pháp cân bằng vi chất'         (Cân bằng vi chất)
--   'Phẫu thuật nhổ răng khôn'           (NHỔ RĂNG)
--
-- PHẢI loại theo product_category, KHÔNG phải product_group: 'PTTM HÀM MẶT'
-- tồn tại ở cả 2 cấp — category có 269 sản phẩm, group có 952 (gồm 24 category
-- con: NHỔ RĂNG, NIỀNG RĂNG, RĂNG SỨ, CẤY GHÉP IMPLANT, ALL-ON...). Loại theo
-- group sẽ mất nhóm NHỔ RĂNG và sai số (T8/2026 hụt 3.500.000).
--
-- WHITELIST NGUỒN — mảnh quyết định để khớp báo cáo, chỉ nhận 3 nhóm:
--   '%hợp tác doanh nghiệp%' : bắt CẢ HAI biến thể 'MD - Hợp tác doanh nghiệp'
--      và 'MO - Hợp tác Doanh nghiệp' (khác tiền tố MD/MO lẫn hoa/thường chữ
--      'Doanh') — bắt buộc dùng ilike, dùng '=' sẽ sót 14 dòng / 427.000.000.
--   '%hợp tác%bệnh viện%'    : 'Hợp tác_Bệnh viện HH Hồ Chí Minh' và
--      'Hợp tác_Bệnh viện HH Hà Nội'.
--   '%ctv khách hàng%'       : 'ML - CTV Khách hàng'.
-- Whitelist loại 'Hợp tác_PR Bà Triệu' — T7/2026 là 2 dòng / 46.000.000 (Cấy
-- mỡ toàn mặt BIOFAT 31tr + IV cân bằng vi chất 15tr), không phải LGBT. Thiếu
-- whitelist thì T7 vọt từ 130.080.000 lên 176.080.000.
--
-- 3 join đều 1-1 (xem chi tiết ở rhh_doanh_so_lgbt_erp_hh). Nhắc lại điểm dễ
-- sai nhất: view_stag_products PHẢI join kèm brand_etl vì product_id không
-- unique toàn cục.
--
-- ĐÃ ĐỐI CHIẾU với báo cáo người dùng:
--   T8/2026 = 309.055.000 (21 dòng) — KHỚP TUYỆT ĐỐI.
--   T7/2026 = 130.080.000 (10 dòng) vs 125.080.000 người dùng đưa — lệch đúng
--     1 phiếu 'PDC/2026/3259' (TRẦN THỊ HỒNG HẠNH, 5.000.000, LGBT - Cắt ngực,
--     nguồn MO - Hợp tác doanh nghiệp). Người dùng đã xác nhận phiếu này CÓ
--     trong hệ thống — file xuất của họ thiếu dòng, model đúng.
--
-- spt.payment ÂM là bình thường (cả PDC lẫn phiếu thu/hoàn) — KHÔNG đảo dấu.

select
    date_trunc('month', spt.payment_date)::date as thang,
    spt.payment_date as ngay,
    spt.ma_phieu,
    spt.payment_type,
    spt.ma_phieu ilike 'CUST.IN%' as la_coc,
    'VP Thương hiệu Kangnam'::text as phap_nhan,
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
where spt.brand_etl  = 1
  and spt.company_id = 54
  and p.product_category <> 'PTTM HÀM MẶT'
  and (
          s.source ilike '%hợp tác doanh nghiệp%'
       or s.source ilike '%hợp tác%bệnh viện%'
       or s.source ilike '%ctv khách hàng%'
      )
