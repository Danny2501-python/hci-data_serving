-- Bảng Kế hoạch/target theo tháng "cho Tableau" (grain: brand + chi_nhanh + nam + thang):
--   - Kangnam/Paris/Hồng Hà: từ ggs_target_company (active=true) — đã đối chiếu khớp CHÍNH XÁC
--     với số đang dùng trong data_demo/dashboard.html (VD Kangnam T1/2026 = 66.541.228.000, khớp
--     100%), có sẵn breakdown theo company/chi nhánh (bonus so với dashboard.html — dashboard chỉ
--     có KH cấp thương hiệu, không có cấp chi nhánh).
--   - Tiêu Hóa Việt: KHÔNG có trong ggs_target_company (kiểm tra 2026-08-31, bảng chỉ có
--     Kangnam/Paris/Hồng Hà) — dùng tạm seed_target_thv_2026_mockup (số đã chốt thủ công trong
--     BC quản trị năm 2026.xlsx, đang dùng trong dashboard.html, chỉ có tới T7/2026). Nếu sau này
--     ggs_target_company có thêm THV, xoá nhánh UNION seed, đọc thẳng từ DB.
-- Cột "nguon_du_lieu" để phân biệt DB_LIVE / MOCKUP_TARGET_THV khi audit lại.

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
  and brand in ('Kangnam', 'Paris', 'Hồng Hà')

union all

select
    brand,
    cast(null as varchar) as chi_nhanh,
    nam,
    thang,
    target,
    'MOCKUP_TARGET_THV' as nguon_du_lieu
from {{ ref('seed_target_thv_2026_mockup') }}
