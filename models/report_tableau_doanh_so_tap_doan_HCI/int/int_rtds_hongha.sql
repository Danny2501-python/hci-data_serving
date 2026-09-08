-- Doanh số Hồng Hà (EHC, brand_etl=4 bên CRM) — nguồn CHÍNH là ehc_tb_invoice (đúng pattern
-- fct_doanhso_ehc_theo_nguon.sql đã có sẵn trong repo: chỉ tính dm_invoice_typeid 1 (Phiếu thu) và
-- 2 (Hoàn tiền, đảo dấu) là doanh số thật — các loại phiếu khác (Tạm ứng/Miễn giảm/Thu 0đ/Chi BHYT)
-- KHÔNG tính vào doanh số, giữ nguyên logic gốc, không tự mở rộng thêm loại phiếu).
--
-- Chi tiết booking/dịch vụ/nguồn: bắc cầu `ehc_tb_patientrecord.id_booking` ↔ `crm_lead.name` (LỌC
-- brand_etl=4 TRƯỚC khi so khớp — mã booking trùng ngẫu nhiên giữa các brand, đã verify thực tế
-- 2026-08-27, xem lịch sử trao đổi). Coverage cầu này ~85-100% từ T8/2025 trở đi (sau khi backfill
-- crm_lead từ sandbox, mục 2026-08-27) — các dòng KHÔNG khớp được (đa số trước T8/2025, hoặc bệnh
-- nhân không qua CRM) vẫn giữ nguyên dòng doanh số, chỉ để trống ma_booking/nhom_dich_vu/san_pham
-- (co_chi_tiet_booking=false) — KHÔNG loại bỏ khỏi báo cáo.
--
-- ⚠ 1 booking (crm_id) có thể có NHIỀU dòng crm_line/crm_line_product (nhiều dịch vụ trong 1 lần
-- khám), nhưng 1 invoice EHC = 1 dòng doanh số duy nhất — nếu join thẳng sẽ FAN-OUT nhân bản doanh
-- số. Dùng `distinct on (crm_id)` lấy đúng 1 dòng dịch vụ ĐẠI DIỆN (không phải đầy đủ mọi dịch vụ
-- của booking đó) — ưu tiên id nhỏ nhất, chọn tuỳ ý vì mục đích chỉ để có 1 nhãn dịch vụ tham khảo,
-- KHÔNG phải để tính lại doanh số theo dịch vụ (doanh số vẫn lấy nguyên từ invoice, không bị ảnh
-- hưởng bởi việc chọn dòng nào).

{{ config(materialized='table') }}

with cline_union as (
    select crm_id, product_id, brand_etl, id from {{ ref('stg_rtds_crm_line') }}
    union all
    select booking_id as crm_id, product_id, brand_etl, id from {{ ref('stg_rtds_crm_line_product') }}
),

cline_one as (
    select distinct on (crm_id, brand_etl) crm_id, product_id, brand_etl
    from cline_union
    where brand_etl = 4
    order by crm_id, brand_etl, id
),

base as (
    select
        iv.invoiceid,
        iv.patientrecordid,
        iv.invoicedate,
        case iv.dm_invoice_typeid when 1 then iv.sotienphieu when 2 then -iv.sotienphieu end as so_tien
    from {{ ref('stg_rtds_ehc_tb_invoice') }} iv
    where iv.huyphieu_status = 0
      and iv.invoiceid not in (select invoiceid from {{ ref('stg_rtds_ehc_tb_invoicerequest') }})
),

pr as (
    select patientrecordid, patientcode, patientname, nguoigioithieuid, id_booking
    from {{ ref('stg_rtds_ehc_tb_patientrecord') }}
),

ng as (
    select nguoigioithieuid, nguoigioithieuname, dm_hoahongnguoigioithieu_nguoigioithieuid
    from {{ ref('stg_rtds_ehc_tb_nguoigioithieu') }}
),

nhom_ng as (
    select dm_hoahongnguoigioithieu_nguoigioithieuid, dm_hoahongnguoigioithieu_nguoigioithieuname
    from {{ ref('stg_rtds_ehc_nhom_nguon') }}
),

bridge as (
    select id as crm_lead_id, name as ma_booking, source_id
    from {{ ref('stg_rtds_crm_lead') }}
    where brand_etl = 4
)

select
    'Hồng Hà' as brand,
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
    'Hồng Hà' as chi_nhanh,
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
