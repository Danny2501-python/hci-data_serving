-- Doanh số Paris (brand_etl=3) — y hệt logic int_rtds_kangnam.sql, chỉ khác brand_etl. Xem chú
-- thích đầy đủ ở file đó.
-- ⚠ LOẠI các chi nhánh đã đóng cửa (var `closed_company_ids`) — danh sách lấy từ Tableau workbook
-- KANGNAM (áp dụng chung cho cả Kangnam/Paris vì Custom SQL gốc gộp brand_id IN (1,3) rồi mới lọc
-- company_id, KHÔNG tách riêng theo brand) — mới verify số Kangnam, Paris CHƯA đối chiếu số thực tế,
-- xem lịch sử trao đổi 2026-09-08.
-- (Lỗi is_delete/tombstone CDC đã sửa NGAY TẠI GỐC — xem chú thích ở int_rtds_kangnam.sql.)
-- ⚠⚠ (2026-09-11) `so_tien` giờ là "DOANH SỐ TÍNH KPI" (loại thêm is_no_kpi + nguồn CBNV/đối ngoại/
-- TPM/bác sĩ hợp tác nội bộ), KHÔNG CÒN khớp "DOANH SỐ TỔNG" — xem chú thích đầy đủ + lý do ở
-- int_rtds_kangnam.sql. Paris CHƯA verify riêng số GB_result (mới verify Kangnam T6/2026).

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
  and coalesce(spt.company_id, 0) not in ({{ var('closed_company_ids') | join(',') }})
  and not coalesce(sp.is_no_kpi, false)
  and not (
    coalesce(cl.source_id, 0) in ({{ var('kpi_exclude_source_ids_cbnv') | join(',') }})
    or ss.source ilike '%cbnv%'
  )
  and not (
    coalesce(cl.source_id, 0) in ({{ var('kpi_exclude_source_ids_doi_ngoai') | join(',') }})
    or ss.source ilike '%đối ngoại%'
  )
  and not (
    coalesce(cl.source_id, 0) in ({{ var('kpi_exclude_source_ids_tpm') | join(',') }})
    or ss.source ilike '%thuê phòng mổ%'
    or ss.source ilike '%tpm%'
  )
  and not (
    spt.payment_date >= date '{{ var("kpi_exclude_bs_hop_tac_tu_ngay") }}'
    and (
      coalesce(cl.source_id, 0) in ({{ var('kpi_exclude_source_ids_bs_hop_tac') | join(',') }})
      or ss.source ilike '%bác sĩ hợp tác%'
    )
  )
  and coalesce(ss.source, '') <> 'All services'
