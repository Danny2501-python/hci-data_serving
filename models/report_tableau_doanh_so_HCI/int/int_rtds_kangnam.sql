-- Doanh số Kangnam (brand_etl=1), grain khách hàng+booking — nguồn stag_payment_transfer (đã
-- cutover dbt, xem models/erp_staging/payment_transfer), join crm_lead (khách hàng/mã booking/
-- nguồn), view_stag_products (dịch vụ/sản phẩm — join thẳng qua spt.product_id, KHÔNG cần qua
-- crm_line vì product_id đã có sẵn trên chính stag_payment_transfer), m_res_company (chi nhánh).
-- Pattern join THAM KHẢO report_doanh_so_tap_doan_HCI.sql (đã có, brand Kangnam/Paris) + mở rộng
-- thêm cột dịch vụ/sản phẩm/mã booking mà model đó chưa có.
-- ⚠ PHẢI lọc brand_etl TRƯỚC khi join theo id (crm_id/company_id) — id có thể trùng chéo giữa các
-- brand (đã xác minh nhiều lần trong dự án này, xem lịch sử trao đổi 2026-08-26/27).

{{ config(materialized='table') }}

select
    'Kangnam' as brand,
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
    select * from {{ ref('stg_rtds_crm_lead') }} where brand_etl = 1
) cl on cl.id = spt.crm_id
left join (
    select * from {{ ref('stg_rtds_m_res_company') }} where brand_etl = 1
) mrc on mrc.id = spt.company_id
left join {{ ref('stg_rtds_view_stag_products') }} sp on sp.product_id = spt.product_id and sp.brand_etl = spt.brand_etl
left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = cl.source_id
where spt.brand_etl = 1
