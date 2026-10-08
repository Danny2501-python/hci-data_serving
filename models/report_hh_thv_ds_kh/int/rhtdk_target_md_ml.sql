-- Mục tiêu doanh số MD / ML theo tháng của 2 thương hiệu (1 dòng = 1 tháng x
-- 1 brand x 1 loại):
--   - Hồng Hà       (brand_etl = 4): seed seed_hh_target_md_ml (người dùng
--     cung cấp: md = Nguồn MD, ml = Nguồn Offline), 2026.
--   - Tiêu hóa Việt (brand_etl = 8): rtr_target_latest, chi_tieu 'md' / 'ml'
--     (T7 -> T12/2026; md = md_khong_thuoc cùng giá trị).

with hh as (
    select
        4                               as brand_etl,
        'Hồng Hà'::text                 as ten_thuong_hieu,
        t.ngay_dau_thang::date          as ngay_dau_thang,
        t.chi_tieu::text                as loai_chi_tieu,
        t.target::double precision      as chi_tieu
    from {{ ref('seed_hh_target_md_ml') }} t
),

thv as (
    select
        8                               as brand_etl,
        'Tiêu hóa Việt'::text           as ten_thuong_hieu,
        t.ngay_dau_thang::date          as ngay_dau_thang,
        t.chi_tieu::text                as loai_chi_tieu,
        t.target::double precision      as chi_tieu
    from {{ ref('rtr_target_latest') }} t
    where t.chi_tieu in ('md', 'ml')
)

select * from hh
union all
select * from thv
