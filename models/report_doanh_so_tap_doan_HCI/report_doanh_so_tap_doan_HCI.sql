-- Gom doanh số 4 đơn vị trong tập đoàn HCI vào 1 bảng, 1 dòng = 1 giao dịch thu tiền:
--   1. Kangnam        — erp_staging/payment_transfer (stag_payment_transfer), brand_etl = 1
--   2. Paris           — erp_staging/payment_transfer (stag_payment_transfer), brand_etl = 3
--   3. Hồng Hà         — fct_doanhso_ehc (models/fct_doanhso_ehc/fct_doanhso_ehc_theo_nguon.sql)
--   4. Tiêu Hóa Việt   — fct_doanhso_ehc_vde (models/fct_doanhso_ehc/fct_doanhso_ehc_vde_theo_nguon.sql)
--
-- Kangnam/Paris là dữ liệu CRM (booking/thanh toán dịch vụ), Hồng Hà/VDE là dữ liệu HIS bệnh viện
-- (phiếu thu EHC) — 2 hệ nguồn khác nhau nên chỉ gom được các cột chung: brand, ngày, số tiền,
-- mã/tên khách hàng.
--
-- Lưu ý join crm_lead/m_res_company: PHẢI lọc brand_etl trước khi join theo id (crm_id/company_id)
-- — id có thể trùng chéo giữa các brand, join không kèm brand_etl sẽ lấy nhầm dữ liệu brand khác
-- (đã verify: join m_res_company không lọc brand_etl bị fan-out gấp đôi số dòng do trùng id).
--
-- chi_nhanh: Kangnam/Paris lấy tên chi nhánh thật qua company_id -> m_res_company.name (nhiều chi
-- nhánh/brand). Hồng Hà/VDE là bệnh viện 1 địa điểm duy nhất (ehc_tb_room.hospitalunitid luôn = 0,
-- không có bảng chi nhánh) nên gán cứng = tên brand.
--
-- nguon/nhom_nguon_khach (Kangnam/Paris): lấy qua crm_lead.source_id -> stag_sources.old_id
-- (source = Nguồn, newcat_source = Nhóm nguồn khách), KHÔNG join thẳng utm_source.category_id ->
-- crm_category_source như hướng ban đầu — đã thử và category_id không khớp bảng đó (~99.7% miss,
-- 2 hệ id khác nhau). stag_sources là bảng đã tổng hợp sẵn cùng ý nghĩa từ utm_source, brand_etl
-- luôn NULL (nguồn dùng chung mọi brand, không cần lọc brand_etl khi join), old_id là duy nhất
-- (không fan-out), match ~99.8% (169/75.675 thiếu ở Kangnam, source_id cũ không còn trong danh mục).
{{ config(materialized='table') }}

with kangnam as (
    select
        spt.id::text as ma_giao_dich,
        cl.code_customer as ma_khach_hang,
        cl.contact_name as ten_khach_hang,
        spt.payment_date as ngay,
        spt.payment::numeric as so_tien,
        ss.source as nguon,
        ss.newcat_source as nhom_nguon_khach,
        mrc.name as chi_nhanh
    from {{ source('crm_base', 'stag_payment_transfer') }} spt
    left join (
        select * from {{ source('crm_base', 'crm_lead') }} where brand_etl = 1
    ) cl on cl.id = spt.crm_id
    left join (
        select * from {{ source('crm_base', 'm_res_company') }} where brand_etl = 1
    ) mrc on mrc.id = spt.company_id
    left join {{ source('crm_base', 'stag_sources') }} ss on ss.old_id = cl.source_id
    where spt.brand_etl = 1
),

paris as (
    select
        spt.id::text as ma_giao_dich,
        cl.code_customer as ma_khach_hang,
        cl.contact_name as ten_khach_hang,
        spt.payment_date as ngay,
        spt.payment::numeric as so_tien,
        ss.source as nguon,
        ss.newcat_source as nhom_nguon_khach,
        mrc.name as chi_nhanh
    from {{ source('crm_base', 'stag_payment_transfer') }} spt
    left join (
        select * from {{ source('crm_base', 'crm_lead') }} where brand_etl = 3
    ) cl on cl.id = spt.crm_id
    left join (
        select * from {{ source('crm_base', 'm_res_company') }} where brand_etl = 3
    ) mrc on mrc.id = spt.company_id
    left join {{ source('crm_base', 'stag_sources') }} ss on ss.old_id = cl.source_id
    where spt.brand_etl = 3
),

hongha as (
    select
        ma_phieu::text as ma_giao_dich,
        ma_benh_nhan as ma_khach_hang,
        ten_benh_nhan as ten_khach_hang,
        ngay_thu::date as ngay,
        so_tien_phieu::numeric as so_tien,
        nguon,
        nhom_nguon_khach,
        'Hồng Hà' as chi_nhanh
    from {{ ref('fct_doanhso_ehc_theo_nguon') }}
),

vde as (
    select
        ma_phieu::text as ma_giao_dich,
        ma_benh_nhan as ma_khach_hang,
        ten_benh_nhan as ten_khach_hang,
        ngay_thu::date as ngay,
        so_tien_phieu::numeric as so_tien,
        nguon,
        nhom_nguon_khach,
        'Tiêu Hóa Việt' as chi_nhanh
    from {{ ref('fct_doanhso_ehc_vde_theo_nguon') }}
)

select 'Kangnam' as brand, 'CRM' as nguon_he_thong, * from kangnam
union all
select 'Paris' as brand, 'CRM' as nguon_he_thong, * from paris
union all
select 'Hồng Hà' as brand, 'EHC' as nguon_he_thong, * from hongha
union all
select 'Tiêu Hóa Việt' as brand, 'EHC' as nguon_he_thong, * from vde
