-- Doanh số LGBT (ERP) — GỘP 2 pháp nhân. Toàn bộ logic nằm ở 2 model con,
-- model này chỉ union lại để lấy con số tổng:
--   - rhh_doanh_so_lgbt_erp_hh   : BV Hồng Hà (brand_etl = 4)
--   - rhh_doanh_so_lgbt_erp_vpth : VP Thương hiệu Kangnam (brand 1 / cty 54)
--
-- Hai model con dùng CÁCH LỌC NGƯỢC NHAU (Hồng Hà lọc theo nhóm DV chứa LGBT;
-- VP Thương hiệu lọc trừ 'PTTM HÀM MẶT') — xem comment trong từng file.
--
-- Nguồn ERP, BỔ SUNG cho rhh_doanh_so_lgbt (lấy từ EHC/HIS, phòng khám 276).
-- Cộng 2 nguồn thì phải trừ cọc một bên vì khoản cọc CUST.IN có ở cả hai —
-- dùng cột `la_coc` ở đây, hoặc `pl <> 'Cọc trong tháng'` bên EHC.
--
-- Số 2026 (đến 16/09):
--   thang   BV Hồng Hà    VP Thương hiệu      Tổng ERP
--   T1      14.000.000     248.420.000     262.420.000
--   T2               0     265.400.000     265.400.000
--   T3       1.000.000     305.020.000     306.020.000
--   T4       5.000.000     335.380.000     340.380.000
--   T5               0     122.220.000     122.220.000
--   T6               0     242.360.000     242.360.000
--   T7       2.000.000     130.080.000     132.080.000
--   T8       2.500.000     309.055.000     311.555.000
--   T9               0      81.500.000      81.500.000

select * from {{ ref('rhh_doanh_so_lgbt_erp_hh') }}
union all
select * from {{ ref('rhh_doanh_so_lgbt_erp_vpth') }}
