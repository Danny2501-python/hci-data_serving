-- Doanh số Tiêu Hóa Việt (EHC, brand_etl=8 bên CRM).
-- ⚠ (2026-09-26) ĐỔI NGUỒN: lấy thẳng từ mart `report_thv_revenue` (folder report_thv_revenue, do
-- hahth xây) thay cho logic tự tính cũ trên ehc_tb_invoice_thv — theo yêu cầu người dùng, để báo cáo
-- tập đoàn HCI dùng chung 1 logic doanh số THV với báo cáo riêng của THV. Logic doanh số/nhóm nguồn
-- xem `models/report_thv_revenue/LOGIC.md`. Khác biệt so với bản cũ:
--   - GỒM cả nhà thuốc (nguon_doanh_thu = 'nha_thuoc'), bản cũ chỉ có dịch vụ.
--   - Hoàn tiền (2) / Hoàn ứng (4) đã đảo dấu sẵn trong sotienphieu → cộng thẳng.
--   - LOẠI nhóm nguồn báo cáo CBNV (giống report_thv_revenue_target) — đối chiếu T6-T8/2026 khớp số
--     chốt BC quản trị (seed_doanh_so_chot_hongha_thv) tới hàng trăm đồng ở T6/T8, T7 lệch ~3,35tr.
--   - `nguon` = tên người giới thiệu EHC, `nhom_nguon_khach` = nhom_nguon_baocao (MD/ML/Loyalty/VL...)
--     của hahth, không còn lấy theo stag_sources của ERP.
-- Bảng nguồn không có invoiceid/patientcode → ma_giao_dich = nguon_doanh_thu + sophieu, patientcode
-- lấy lại từ patientrecord theo patientrecordid (nhà thuốc bán lẻ không có hồ sơ → NULL).
-- Nhóm dịch vụ/sản phẩm vẫn bắc cầu id_booking ↔ crm_lead.name như cũ (chỉ cho dòng dịch vụ; dòng nhà
-- thuốc gán nhom_dich_vu = 'Nhà thuốc').
-- (Var `closed_company_ids` KHÔNG áp dụng ở đây, xem chú thích ở int_rtds_hongha.sql.)

{{ config(materialized='table') }}

with cline_union as (
    select crm_id, product_id, brand_etl, id from {{ ref('stg_rtds_crm_line') }}
    union all
    select booking_id as crm_id, product_id, brand_etl, id from {{ ref('stg_rtds_crm_line_product') }}
),

cline_one as (
    select distinct on (crm_id, brand_etl) crm_id, product_id, brand_etl
    from cline_union
    where brand_etl = 8
    order by crm_id, brand_etl, id
),

base as (
    select *
    from {{ ref('report_thv_revenue') }}
    where coalesce(nhom_nguon_baocao, '') <> 'CBNV'
),

pr as (
    select patientrecordid, patientcode
    from {{ ref('stg_rtds_ehc_tb_patientrecord_thv') }}
),

bridge as (
    select id as crm_lead_id, name as ma_booking
    from {{ ref('stg_rtds_crm_lead') }}
    where brand_etl = 8
)

select
    'Tiêu Hóa Việt' as brand,
    'EHC' as nguon_he_thong,
    b.nguon_doanh_thu || '-' || b.sophieu as ma_giao_dich,
    (bridge.crm_lead_id is not null) as co_chi_tiet_booking,
    b.invoicedate::date as ngay,
    extract(year from b.invoicedate)::int as nam,
    extract(month from b.invoicedate)::int as thang,
    pr.patientcode as ma_khach_hang,
    b.patientname as ten_khach_hang,
    bridge.ma_booking as ma_booking,
    case when b.nguon_doanh_thu = 'nha_thuoc' then 'Nhà thuốc' else sp.product_category end as nhom_dich_vu,
    case when b.nguon_doanh_thu = 'nha_thuoc' then null else sp.product end as san_pham,
    'Phòng Khám Tiêu Hóa Việt' as chi_nhanh,  -- = m_res_company id 57 brand_etl 8 (khớp target/khách hàng)
    b.nguoigioithieu as nguon,
    b.nhom_nguon_baocao as nhom_nguon_khach,
    b.sotienphieu::numeric as so_tien,
    -- (2026-09-26) MD/ML theo nhóm báo cáo của hahth (nhom_md_ml_baocao: MD/ML/MO/CBNV — CBNV đã loại
    -- ở base): MD → MD, còn lại (ML, MO, không nguồn) → ML (user chốt).
    case when b.nhom_md_ml_baocao = 'MD' then 'MD' else 'ML' end as nhom_md_ml
from base b
left join pr on pr.patientrecordid = b.patientrecordid
left join bridge on bridge.ma_booking = b.id_booking
left join cline_one cl2 on cl2.crm_id = bridge.crm_lead_id and b.nguon_doanh_thu = 'dich_vu'
left join {{ ref('stg_rtds_view_stag_products') }} sp on sp.product_id = cl2.product_id and sp.brand_etl = cl2.brand_etl
