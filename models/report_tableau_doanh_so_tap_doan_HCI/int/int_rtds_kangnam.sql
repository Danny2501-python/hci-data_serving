-- Doanh số Kangnam (brand_etl=1), grain khách hàng+booking — nguồn stag_payment_transfer (đã
-- cutover dbt, xem models/erp_staging/payment_transfer), join crm_lead (khách hàng/mã booking/
-- nguồn), view_stag_products (dịch vụ/sản phẩm — join thẳng qua spt.product_id, KHÔNG cần qua
-- crm_line vì product_id đã có sẵn trên chính stag_payment_transfer), m_res_company (chi nhánh).
-- Pattern join THAM KHẢO report_doanh_so_tap_doan_HCI.sql (đã có, brand Kangnam/Paris) + mở rộng
-- thêm cột dịch vụ/sản phẩm/mã booking mà model đó chưa có.
-- ⚠ PHẢI lọc brand_etl TRƯỚC khi join theo id (crm_id/company_id) — id có thể trùng chéo giữa các
-- brand (đã xác minh nhiều lần trong dự án này, xem lịch sử trao đổi 2026-08-26/27).
-- ⚠ LOẠI các chi nhánh đã đóng cửa (var `closed_company_ids`) để khớp logic Tableau workbook
-- "KANGNAM - BỘ CHỈ SỐ KINH DOANH - 2025.twbx" (đã đối chiếu khớp số Kangnam T8/2026: 77.241.180.359đ,
-- xem lịch sử trao đổi 2026-09-08) — Tableau dùng ZN([company_id]) IN (...) nên company_id NULL
-- KHÔNG bị loại, giữ nguyên hành vi đó bằng coalesce(spt.company_id, 0) dưới đây.
-- (Lỗi is_delete/tombstone CDC ở crm_account_payment_detail (từng gây lệch +56.300.000đ T8/2026 so
-- với Tableau) đã sửa NGAY TẠI GỐC — models/erp_staging/payment_transfer/stg/stg_sptr_crm_account_*
-- /stg_sptr_crm_transfer_payment_line.sql — stag_payment_transfer giờ đã sạch, không cần lọc lại ở
-- report này nữa. Xem models/erp_staging/payment_transfer/knowledge.md mục 3.)
--
-- ⚠⚠ (2026-09-11) `so_tien` giờ là "DOANH SỐ TÍNH KPI" (khớp sheet GB_result trong Tableau workbook
-- KANGNAM, T6/2026: 80.943.387.448đ), KHÔNG CÒN khớp tab "DOANH SỐ TỔNG" (77.241.180.359đ T8/2026,
-- xem comment phía trên) nữa — đây là 2 khái niệm CỐ Ý khác nhau trong chính Tableau, không phải
-- lỗi. GB_result loại thêm (ngoài closed_company_ids ở trên):
--   1. Sản phẩm/dịch vụ có view_stag_products.is_no_kpi = true.
--   2. Nguồn khách CBNV (nhân viên nội bộ mua dịch vụ), "đối ngoại", "thuê phòng mổ (TPM)".
--   3. Nguồn "bác sĩ hợp tác nội bộ" — CHỈ loại từ 13/06/2024 trở đi (đúng comment gốc Tableau).
-- Danh sách source_id lấy từ Tableau workbook KANGNAM (sheet GB_result, field is_kpi_branch) — xem
-- lịch sử trao đổi 2026-09-11. Nguồn khách ở đây lấy qua cl.source_id/ss.source (booking source) —
-- ĐÚNG khớp cách Tableau/report_kpi_bonus_commission tự lấy source_id/source (cùng join
-- ss.old_id = cl.source_id, xem int_rkbc_base_payment.sql).
-- ⚠ [2026-09-12, ĐÃ SỬA] `ss.source ilike '...'` khi ss.source NULL (source_id không có trong
-- stag_sources, VD source_id=783 "Mobile app") trả về NULL chứ không phải false — NOT(false OR NULL)
-- = NULL, WHERE loại mất dòng đó dù đáng lẽ phải giữ (gây thiếu 98 dòng/366.185.000đ T8/2026 so với
-- report_kpi_bonus_commission — phát hiện qua đối chiếu T6-T8/2026, GB_result T6 khớp nhưng T7/T8
-- lệch). Tableau gốc luôn bọc IFNULL(...,FALSE) quanh các CONTAINS/REGEXP này — PHẢI bọc
-- coalesce(... , false) quanh từng `ss.source ilike` dưới đây, không được bỏ sót.

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
    spt.payment::numeric as so_tien,
    -- (2026-09-26) Nhóm nguồn MD/ML theo class_source_inidcate của workbook "Bộ chỉ số kinh doanh"
    -- — xem macros/rtds_nhom_md_ml.sql.
    -- (2026-09-28) User chốt: doanh số sản phẩm (nhóm 'SAN PHAM') tách riêng nhóm 'SP' — KHÔNG nằm trong
    -- MD/ML (tổng DS KPI giữ nguyên = MD + ML + SP). THẺ DA LIỄU vẫn theo nguồn như dịch vụ.
    case
        when sp.product_category = 'SAN PHAM' then 'SP'
        else {{ rtds_nhom_md_ml('cl.source_id', 'ss.category_id', 'ss.source') }}
    end as nhom_md_ml,
    -- (2026-09-28) Thêm his_service_type (view_stag_products) + source_id (crm_lead) theo yêu cầu user.
    sp.his_service_type::text as his_service_type,
    cl.source_id::int as source_id
from {{ ref('stag_payment_transfer') }} spt
left join (
    select * from {{ ref('stg_rtds_crm_lead') }} where brand_etl = 1
) cl on cl.id = spt.crm_id
left join (
    select * from {{ ref('stg_rtds_m_res_company') }} where brand_etl = 1
) mrc on mrc.id = {{ rtds_company_id_gop('spt.company_id', 'spt.payment_date', 'spt.brand_etl') }}  -- (2026-09-29) Gộp chi nhánh theo var rtds_gop_chi_nhanh (BV Thẩm mỹ KN 12 → KN Sài Gòn 4 từ 01/08/2026)
left join {{ ref('stg_rtds_view_stag_products') }} sp on sp.product_id = spt.product_id and sp.brand_etl = spt.brand_etl
left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = cl.source_id
where spt.brand_etl = 1
  and coalesce(spt.company_id, 0) not in ({{ var('closed_company_ids') | join(',') }})
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
  and coalesce(ss.source, '') <> 'All services'
