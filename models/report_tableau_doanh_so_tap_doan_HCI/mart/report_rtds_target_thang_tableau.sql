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

select
    brand,
    company as chi_nhanh,
    extract(year from time)::int as nam,
    extract(month from time)::int as thang,
    target,
    'DB_LIVE' as nguon_du_lieu
from {{ ref('stg_rtds_ggs_target_company') }}
where active = true
  and brand in ('Kangnam', 'Paris', 'Hồng Hà', 'Tiêu Hóa Việt')
