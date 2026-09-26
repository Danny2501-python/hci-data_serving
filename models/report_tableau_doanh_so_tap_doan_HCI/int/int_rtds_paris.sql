-- Doanh số Paris (brand_etl=3) — y hệt logic int_rtds_kangnam.sql, chỉ khác brand_etl. Xem chú
-- thích đầy đủ ở file đó.
-- ⚠⚠ [2026-09-12, ĐÃ SỬA — BỎ HẲN] `closed_company_ids` (danh sách chi nhánh Kangnam đã đóng cửa)
-- TỪNG bị áp nhầm cho cả Paris (giả định sai 2026-09-08: "công ty đóng cửa dùng chung 2 brand" —
-- KHÔNG đúng, company_id trùng chéo giữa các brand). Đã xác minh thực tế: company_id=38 (nằm trong
-- danh sách) = "NHA KHOA PARIS BUÔN MÊ THUỘT" — 1 chi nhánh Paris ĐANG HOẠT ĐỘNG — bị loại nhầm, gây
-- lệch 6.150.000đ/4 dòng T6/2026 khi đối chiếu với `report_kpi_bonus_commission`/workbook
-- "PARIS - TỔNG HỢP DOANH SỐ THƯƠNG HIỆU.twbx" (workbook Paris KHÔNG hề có filter loại chi nhánh nào
-- — company filter để "all"). KHÔNG áp `closed_company_ids` cho Paris nữa.
-- (Lỗi is_delete/tombstone CDC đã sửa NGAY TẠI GỐC — xem chú thích ở int_rtds_kangnam.sql.)
-- ⚠⚠ (2026-09-11) `so_tien` giờ là "DOANH SỐ TÍNH KPI" (loại thêm is_no_kpi + nguồn CBNV/đối ngoại/
-- TPM/bác sĩ hợp tác nội bộ), KHÔNG CÒN khớp "DOANH SỐ TỔNG" — xem chú thích đầy đủ + lý do ở
-- int_rtds_kangnam.sql. Paris CHƯA verify riêng số GB_result (mới verify Kangnam T6/2026).
-- ⚠ [2026-09-12, ĐÃ SỬA] NULL-propagation ở `ss.source ilike` khi source_id không có trong
-- stag_sources — xem chi tiết ở int_rtds_kangnam.sql (phát hiện qua Kangnam, sửa đồng thời ở đây).
-- ⚠ [2026-09-12] Paris có THÊM 1 điều kiện loại trừ KHÔNG có ở Kangnam GB_result: loại theo
-- `category_source_id` (dịch vụ test covid, phụ thu hóa đơn — var `kpi_exclude_category_source_ids_paris`),
-- lấy từ Tableau workbook "PARIS - TỔNG HỢP DOANH SỐ THƯƠNG HIỆU.twbx" (field
-- T/F_category_source_no_kpi) — user xác nhận trực tiếp. Field `category_source_id` = `ss.category_id`
-- (bảng stag_sources), dùng chung join `ss` đã có sẵn (qua `cl.source_id`).

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
    spt.payment::numeric as so_tien,
    -- (2026-09-26) Nhóm nguồn MD/ML theo class_source_inidcate của workbook "Bộ chỉ số kinh doanh"
    -- — xem macros/rtds_nhom_md_ml.sql.
    {{ rtds_nhom_md_ml('cl.source_id', 'ss.category_id', 'ss.source') }} as nhom_md_ml
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
  and not coalesce(sp.is_no_kpi, false)
  and not (
    coalesce(cl.source_id, 0) in ({{ var('kpi_exclude_source_ids_cbnv') | join(',') }})
    or coalesce(ss.source ilike '%cbnv%', false)
  )
  and not (
    coalesce(cl.source_id, 0) in ({{ var('kpi_exclude_source_ids_doi_ngoai') | join(',') }})
    or coalesce(ss.source ilike '%đối ngoại%', false)
  )
  and not (
    coalesce(cl.source_id, 0) in ({{ var('kpi_exclude_source_ids_tpm') | join(',') }})
    or coalesce(ss.source ilike '%thuê phòng mổ%', false)
    or coalesce(ss.source ilike '%tpm%', false)
  )
  and not (
    spt.payment_date >= date '{{ var("kpi_exclude_bs_hop_tac_tu_ngay") }}'
    and (
      coalesce(cl.source_id, 0) in ({{ var('kpi_exclude_source_ids_bs_hop_tac') | join(',') }})
      or coalesce(ss.source ilike '%bác sĩ hợp tác%', false)
    )
  )
  and coalesce(ss.category_id, 0) not in ({{ var('kpi_exclude_category_source_ids_paris') | join(',') }})
  and coalesce(ss.source, '') <> 'All services'
