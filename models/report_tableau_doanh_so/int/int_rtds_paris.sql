-- Doanh số Paris (brand_etl=3) — y hệt logic int_rtds_kangnam.sql, chỉ khác brand_etl. Xem chú
-- thích đầy đủ ở file đó.

{{ config(materialized='table') }}

select
    'Paris' as brand,
    'CRM' as nguon_he_thong,
    spt.id::text as ma_giao_dich,
    (spt.clineid is not null) as co_chi_tiet_booking,
    spt.payment_date as ngay,
    extract(year from spt.payment_date)::int as nam,
    extract(month from spt.payment_date)::int as thang,
    cl.code_customer as ma_khach_hang,
    cl.contact_name as ten_khach_hang,
    cl.name as ma_booking,
    sp.product_category as nhom_dich_vu,
    sp.product as san_pham,
    mrc.name as chi_nhanh,
    ss.source as nguon,
    ss.newcat_source as nhom_nguon_khach,
    spt.payment::numeric as so_tien
from {{ ref('stag_payment_transfer') }} spt
left join (
    select * from {{ ref('stg_rtds_crm_lead') }} where brand_etl = 3
) cl on cl.id = spt.crm_id
left join (
    select * from {{ ref('stg_rtds_m_res_company') }} where brand_etl = 3
) mrc on mrc.id = spt.company_id
left join {{ ref('stg_rtds_view_stag_products') }} sp on sp.product_id = spt.product_id and sp.brand_etl = spt.brand_etl
left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = cl.source_id
where spt.brand_etl = 3
