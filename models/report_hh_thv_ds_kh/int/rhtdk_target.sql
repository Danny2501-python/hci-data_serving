-- Chỉ tiêu doanh số TỔNG theo tháng/năm của 2 thương hiệu (chưa có chỉ tiêu
-- theo nguồn cho HH nên chỉ lấy tổng cho cả 2 brand):
--   - Hồng Hà       (brand_etl = 4): ggs_target_company brand_id = 4, active.
--     2024-2025 mỗi tháng có thêm dòng company_id = 32 target = 0 -> sum theo
--     tháng không bị lệch.
--   - Tiêu hóa Việt (brand_etl = 8): seed rtr_target (bản đang hiệu lực qua
--     rtr_target_latest), chỉ lấy chi_tieu = 'ds' (tổng; md/ml... chồng nhau).

with hh as (
    select
        4                               as brand_etl,
        'Hồng Hà'::text                 as ten_thuong_hieu,
        t.time::date                    as ngay_dau_thang,
        sum(t.target)::double precision as chi_tieu_doanh_so
    from {{ source('rhh_base', 'ggs_target_company') }} t
    where t.brand_id = 4
      and t.active
    group by t.time::date
),

thv as (
    select
        8                               as brand_etl,
        'Tiêu hóa Việt'::text           as ten_thuong_hieu,
        t.ngay_dau_thang::date          as ngay_dau_thang,
        t.target::double precision      as chi_tieu_doanh_so
    from {{ ref('rtr_target_latest') }} t
    where t.chi_tieu = 'ds'
),

gop as (
    select * from hh
    union all
    select * from thv
)

select
    brand_etl,
    ten_thuong_hieu,
    extract(year from ngay_dau_thang)::integer  as nam,
    extract(month from ngay_dau_thang)::integer as thang,
    ngay_dau_thang,
    chi_tieu_doanh_so
from gop
