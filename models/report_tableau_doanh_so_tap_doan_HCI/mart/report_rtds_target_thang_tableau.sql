-- Bảng Kế hoạch/target theo tháng "cho Tableau" (grain: brand + chi_nhanh + nam + thang):
--   - Kangnam/Paris/Hồng Hà: từ ggs_target_company (active=true) — đã đối chiếu khớp CHÍNH XÁC
--     với số đang dùng trong data_demo/dashboard.html (VD Kangnam T1/2026 = 66.541.228.000, khớp
--     100%), có sẵn breakdown theo company/chi nhánh (bonus so với dashboard.html — dashboard chỉ
--     có KH cấp thương hiệu, không có cấp chi nhánh).
--   - Tiêu Hóa Việt: (2026-09-16) ĐÃ CÓ trong ggs_target_company (user tự kéo lại dữ liệu) — XOÁ
--     nhánh UNION seed_target_thv_2026_mockup theo đúng kế hoạch đã ghi sẵn ở đây từ trước, đọc
--     THẲNG từ DB cho cả 4 thương hiệu. Đã đối chiếu: DB có ĐỦ 12 tháng/2026 (mockup cũ chỉ có tới
--     T7/2026) và số liệu T4-T6/2026 đã được CẬP NHẬT LẠI cao hơn mockup cũ (VD T4: 3,6 tỷ → 4,5 tỷ)
--     — mockup cũ giờ lỗi thời, không dùng nữa. `seed_target_thv_2026_mockup.csv` giữ lại trong repo
--     làm tư liệu lịch sử, không còn được ref() ở đâu.
-- Cột "nguon_du_lieu" để phân biệt DB_LIVE / MOCKUP_TARGET_THV khi audit lại — giờ luôn = 'DB_LIVE'
-- vì không còn nhánh mockup nào, giữ lại cột cho tương thích ngược với các model đang dùng nó.

{{ config(materialized='table') }}

-- (2026-09-26) chi_nhanh lấy tên chuẩn từ m_res_company (company_id + brand_etl = brand_id) để khớp
-- với doanh số/khách hàng khi join theo chi nhánh — tên trong ggs_target_company có chỗ lệch:
-- Paris company 20 'NGUYỄN THÁI HỌC' → 'NGUYỄN T.M KHAI' (đúng field company_rename của workbook
-- Kangnam), THV company 57 'TRUNG TÂM NỘI SOI DR GIANG' → 'Phòng Khám Tiêu Hóa Việt'.
select
    t.brand,
    coalesce(mrc.name, t.company) as chi_nhanh,
    extract(year from t.time)::int as nam,
    extract(month from t.time)::int as thang,
    t.target,
    'DB_LIVE' as nguon_du_lieu
from {{ ref('stg_rtds_ggs_target_company') }} t
left join {{ ref('stg_rtds_m_res_company') }} mrc
       on mrc.id = {{ rtds_company_id_gop('t.company_id', 't.time', 't.brand_id') }}  -- (2026-09-29) Gộp chi nhánh theo var rtds_gop_chi_nhanh (BV Thẩm mỹ KN 12 → KN Sài Gòn 4 từ 01/08/2026)
      and mrc.brand_etl = t.brand_id
where t.active = true
  and t.brand in ('Kangnam', 'Paris', 'Hồng Hà', 'Tiêu Hóa Việt')
