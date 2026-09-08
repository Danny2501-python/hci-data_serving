-- Doanh số Tiêu Hóa Việt (EHC, brand_etl=8 bên CRM) — y hệt logic int_rtds_hongha.sql, chỉ khác
-- dùng bộ bảng `_thv` (ehc_tb_invoice_thv/patientrecord_thv/nguoigioithieu_thv/
-- dm_hoahongnguoigioithieu_nguoigioithieu_thv) và brand_etl=8 khi lọc crm_lead/crm_line. Xem chú
-- thích đầy đủ ở int_rtds_hongha.sql. Cầu id_booking cho THV đã verify coverage tốt hơn Hồng Hà
-- (~87-88% xuyên suốt, không giới hạn từ 1 mốc thời gian cụ thể như Hồng Hà) — xem lịch sử trao đổi
-- 2026-08-26/27, model report_thv_sale_online cũng dùng đúng cầu này.

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
    select
        iv.invoiceid,
        iv.patientrecordid,
        iv.invoicedate,
        case iv.dm_invoice_typeid when 1 then iv.sotienphieu when 2 then -iv.sotienphieu end as so_tien
    from {{ ref('stg_rtds_ehc_tb_invoice_thv') }} iv
    where iv.huyphieu_status = 0
      and iv.invoiceid not in (select invoiceid from {{ ref('stg_rtds_ehc_tb_invoicerequest_thv') }})
),

pr as (
    select patientrecordid, patientcode, patientname, nguoigioithieuid, id_booking
    from {{ ref('stg_rtds_ehc_tb_patientrecord_thv') }}
),

ng as (
    select nguoigioithieuid, nguoigioithieuname, dm_hoahongnguoigioithieu_nguoigioithieuid
    from {{ ref('stg_rtds_ehc_tb_nguoigioithieu_thv') }}
),

nhom_ng as (
    select dm_hoahongnguoigioithieu_nguoigioithieuid, dm_hoahongnguoigioithieu_nguoigioithieuname
    from {{ ref('stg_rtds_ehc_nhom_nguon_thv') }}
),

bridge as (
    select id as crm_lead_id, name as ma_booking, source_id
    from {{ ref('stg_rtds_crm_lead') }}
    where brand_etl = 8
)

select
    'Tiêu Hóa Việt' as brand,
    'EHC' as nguon_he_thong,
    b.invoiceid::text as ma_giao_dich,
    (bridge.crm_lead_id is not null) as co_chi_tiet_booking,
    b.invoicedate::date as ngay,
    extract(year from b.invoicedate)::int as nam,
    extract(month from b.invoicedate)::int as thang,
    pr.patientcode as ma_khach_hang,
    pr.patientname as ten_khach_hang,
    bridge.ma_booking as ma_booking,
    sp.product_category as nhom_dich_vu,
    sp.product as san_pham,
    'Tiêu Hóa Việt' as chi_nhanh,
    coalesce(ss.source, ng.nguoigioithieuname) as nguon,
    coalesce(ss.newcat_source, nhom_ng.dm_hoahongnguoigioithieu_nguoigioithieuname) as nhom_nguon_khach,
    b.so_tien::numeric as so_tien
from base b
left join pr on pr.patientrecordid = b.patientrecordid
left join ng on ng.nguoigioithieuid = pr.nguoigioithieuid
left join nhom_ng on nhom_ng.dm_hoahongnguoigioithieu_nguoigioithieuid = ng.dm_hoahongnguoigioithieu_nguoigioithieuid
left join bridge on bridge.ma_booking = pr.id_booking
left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = bridge.source_id
left join cline_one cl2 on cl2.crm_id = bridge.crm_lead_id
left join {{ ref('stg_rtds_view_stag_products') }} sp on sp.product_id = cl2.product_id and sp.brand_etl = cl2.brand_etl
