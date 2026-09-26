-- Doanh số Hồng Hà (EHC, brand_etl=4 bên CRM).
-- ⚠ (2026-09-26) ĐỔI NGUỒN doanh số: lấy thẳng từ mart `rhh_ehc_payment_service` (folder
-- report_hh_revenue, do hahth xây — xem models/report_hh_revenue/LOGIC.md), theo yêu cầu người dùng
-- "khớp logic doanh số theo nhánh hahth". Chỉ lấy `nguon_du_lieu in ('Dịch vụ','Nhà thuốc')` (bỏ
-- 'Target'). Khác biệt so với bản cũ (tự tính trên ehc_tb_invoice, chỉ phiếu loại 1/2):
--   - Viện phí: cùng ngày `invoicedate`, nhưng tính MỌI loại phiếu chưa huỷ (hahth đảo dấu loại 2
--     Hoàn tiền / 4 Hoàn ứng, các loại khác cộng dương) — `sotienphieu` cộng thẳng.
--   - THÊM cọc (`ehc_tb_invoicerequest`, pl = 'Cọc trong tháng', ngày = `ngayyeucau`).
--   - THÊM nhà thuốc (`ehc_tb_invoicemedicine`, ngày = `invoicemedicinedate`), nhom_dich_vu = 'Nhà thuốc'.
--   - KHÔNG loại CBNV (hahth không loại cho Hồng Hà).
-- GIỮ NGUYÊN phần trừ túi ngực/túi mông (union "âm" bên dưới) — hahth không có phần này.
-- THÊM (2026-09-26) phần trừ lương bác sĩ PTTM theo ca ra viện 2026 (union "âm" cuối file, CTE luong_bs).
-- Nguồn/nhóm nguồn/nhóm dịch vụ vẫn bắc cầu id_booking ↔ crm_lead.name (brand_etl=4) như cũ, fallback
-- về người giới thiệu/nhóm hoa hồng EHC mà hahth đã join sẵn.
-- ⚠ 1 booking (crm_id) có thể có NHIỀU dòng crm_line/crm_line_product — dùng `distinct on (crm_id)`
-- lấy 1 dòng dịch vụ ĐẠI DIỆN làm nhãn tham khảo, tránh fan-out (doanh số không bị ảnh hưởng).
--
-- (Var `closed_company_ids` trong dbt_project.yml — loại chi nhánh Kangnam/Paris đã đóng cửa theo
-- Tableau — KHÔNG áp dụng ở đây: hệ EHC không có company_id/m_res_company tương ứng, chi_nhanh
-- Hồng Hà luôn hardcode 1 giá trị duy nhất.)
--
-- ⚠⚠ (2026-09-12) LOẠI THÊM chi phí vật tư túi ngực/túi mông của bệnh nhân thuê phòng mổ (yêu cầu
-- riêng, KHÔNG liên quan is_kpi_branch của Kangnam/Paris) — cộng thêm 1 dòng "âm" (so_tien < 0) cho
-- mỗi dòng vật tư khớp điều kiện, lấy từ `ehc_tb_servicedata` (KHÔNG qua `ehc_tb_invoice` — đã xác
-- minh `invoiceid` trên các dòng vật tư này luôn = 0, không nối được với invoice, nên dùng thẳng
-- `servicedatadate` làm mốc tháng thay vì `invoicedate`).
--
-- Phạm vi bệnh nhân: "cách 1" đã chốt — CHỈ CẦN bệnh nhân từng dùng dịch vụ thuê phòng mổ
-- (`dm_report_groupid = 5`) BẤT KỲ lúc nào, thì loại TOÀN BỘ chi phí túi ngực/túi mông của bệnh nhân
-- đó ở MỌI lần khám khác — KHÔNG giới hạn theo cùng 1 lần khám/hồ sơ với lần thuê phòng mổ.
--
-- Điều kiện nhận diện đúng vật tư túi ngực/túi mông (đã verify thực tế, tránh 2 bẫy dữ liệu):
--   1. `servicecode LIKE 'VT%'` (vật tư, KHÔNG phải dịch vụ) — loại các dòng DỊCH VỤ PTTM/gây mê có
--      tên MÔ TẢ nhắc tới "túi ngực, túi mông" chỉ để nói KHÔNG BAO GỒM (servicecode dạng
--      DVHH.../HHPTTM_.../HHTPM_...) — nếu không lọc theo servicecode, các dòng phí dịch vụ này bị
--      tính nhầm thành "chi phí túi ngực" (đã gặp thực tế, phóng đại chi phí gấp ~2 lần).
--   2. `servicename` phải có tiền tố dạng `(X)` ở đầu (VD "(L) Túi ngực Perle") — theo yêu cầu
--      user: CHỈ loại các dòng có tiền tố size, KHÔNG loại các dòng túi ngực không tiền tố (VD "Túi
--      ngực Mentor MemoryGel BOOST") lẫn phụ kiện không tiền tố (VD "Cây đẩy túi ngực" — dụng cụ hỗ
--      trợ phẫu thuật, không phải bản thân túi ngực).
-- Danh sách 21 mã tiền tố quan sát được: L, XS, CH, TH, QT, KH, C, TL, K, TA, D, ĐT, VA, Đ, BD,
-- DUNG, M, HG, B, HT (không cần liệt kê tường minh — chỉ cần regex bắt có tiền tố `(...)`, không cần
-- khớp đúng danh sách này).
--
-- Đã đối chiếu T1-T9/2026, mức trừ ~18-30%/tháng doanh số Hồng Hà — user đã xác nhận số liệu và
-- cách lọc này (xem lịch sử trao đổi 2026-09-12).

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
    select *
    from {{ ref('rhh_ehc_payment_service') }}
    where nguon_du_lieu in ('Dịch vụ', 'Nhà thuốc')
),

pr as (
    select patientrecordid, patientcode, patientname
    from {{ ref('stg_rtds_ehc_tb_patientrecord') }}
),

-- ⚠ (2026-09-26) crm_lead brand_etl=4 có ~2.000 `name` (mã booking) bị TRÙNG → join thẳng làm
-- FAN-OUT nhân bản doanh số (đã đo: T6/2026 +254tr, T8 −6,9tr do nhân cả phiếu hoàn tiền âm). Khử
-- trùng giống hahth (rhh_ehc_payment_service): giữ bản ghi write_date mới nhất mỗi name.
bridge as (
    select distinct on (name) id as crm_lead_id, name as ma_booking, source_id
    from {{ ref('stg_rtds_crm_lead') }}
    where brand_etl = 4
    order by name, write_date desc nulls last, id desc
),

-- ⚠ Dùng EXISTS (không phải IN (SELECT DISTINCT ...)) — đã đo bằng EXPLAIN ANALYZE trên DB thật:
-- IN(subquery) khiến planner chọn Nested Loop so sánh dư 68 triệu lượt (~18-27s), EXISTS cho
-- planner chọn Nested Loop Semi Join dùng đúng index `patientrecordid` (~8s, nhanh hơn 2,2 lần) —
-- xem lịch sử trao đổi 2026-09-12.
tui_nguc_mong as (
    select
        sd.servicedataid,
        sd.patientrecordid,
        sd.servicedatadate,
        -sd.tongbenhnhan as so_tien
    from {{ ref('stg_rtds_ehc_tb_servicedata') }} sd
    where sd.servicecode like 'VT%'
      and sd.servicename ~ '^\s*\('
      and (sd.servicename ilike '%túi ngực%' or sd.servicename ilike '%túi mông%')
      and exists (
          select 1 from {{ ref('stg_rtds_ehc_tb_servicedata') }} s2
          where s2.patientrecordid = sd.patientrecordid and s2.dm_report_groupid = 5
      )
),

-- ⚠⚠ (2026-09-26) TRỪ LƯƠNG BÁC SĨ PTTM theo ca ra viện (yêu cầu người dùng, CHỈ năm 2026 — 3 mã
-- dưới đây thuộc bảng giá "2026-L", chỉ phát sinh từ 2026-01-02):
--   - Đại phẫu  = DVHH0700 "Dịch vụ PTTM (gây mê)" đơn giá 13.000.000 → trừ 2.000.000/ca.
--   - Tiểu phẫu = DVHH0701 "Dịch vụ PTTM (tiền mê)" 3.900.000 hoặc DVHH0702 "(Gây tê)" 3.000.000
--                 → trừ 500.000/ca.
-- Lọc theo servicecode (KHÔNG theo đơn giá — nhiều dịch vụ khác tình cờ cùng giá: cắt mí, nẹp vít...).
-- 1 ca = 1 hồ sơ bệnh án (patientrecordid) × 1 loại: hồ sơ có nhiều dòng cùng loại chỉ tính 1 ca; hồ
-- sơ có CẢ đại lẫn tiểu phẫu trừ CẢ 2 khoản (người dùng chốt). Chỉ dòng tongbenhnhan > 0 (giống query
-- HIS gốc). Chỉ hồ sơ ĐÃ RA VIỆN (dm_patientrecordstatusid = 1), tháng ghi nhận = tháng
-- medicalrecorddate_out (ngày ra viện) — hồ sơ chưa ra viện (ngày để trống 0001-01-01) chưa trừ.
luong_bs as (
    select
        sd.patientrecordid,
        case when sd.servicecode = 'DVHH0700' then 'dai' else 'tieu' end as loai_phau
    from {{ ref('stg_rtds_ehc_tb_servicedata') }} sd
    where sd.servicecode in ('DVHH0700', 'DVHH0701', 'DVHH0702')
      and sd.tongbenhnhan > 0
      and sd.servicedatadate >= date '2026-01-01'
    group by 1, 2
)

select
    'Hồng Hà' as brand,
    'EHC' as nguon_he_thong,
    case
        when b.nguon_du_lieu = 'Nhà thuốc' then 'nt-' || b.sophieu
        when b.pl = 'Cọc trong tháng' then 'coc-' || coalesce(b.sophieu, b.invoiceid::text)
        else b.invoiceid::text
    end as ma_giao_dich,
    (bridge.crm_lead_id is not null) as co_chi_tiet_booking,
    b.invoicedate::date as ngay,
    extract(year from b.invoicedate)::int as nam,
    extract(month from b.invoicedate)::int as thang,
    b.patientcode as ma_khach_hang,
    b.patientname as ten_khach_hang,
    bridge.ma_booking as ma_booking,
    case when b.nguon_du_lieu = 'Nhà thuốc' then 'Nhà thuốc' else sp.product_category end as nhom_dich_vu,
    case when b.nguon_du_lieu = 'Nhà thuốc' then null else sp.product end as san_pham,
    'Hồng Hà' as chi_nhanh,
    coalesce(ss.source, b.source_ehc) as nguon,
    coalesce(ss.newcat_source, b.dm_hoahongnguoigioithieu_nguoigioithieuname) as nhom_nguon_khach,
    b.sotienphieu::numeric as so_tien
from base b
left join bridge on bridge.ma_booking = b.id_booking
left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = bridge.source_id
left join cline_one cl2 on cl2.crm_id = bridge.crm_lead_id and b.nguon_du_lieu = 'Dịch vụ'
left join {{ ref('stg_rtds_view_stag_products') }} sp on sp.product_id = cl2.product_id and sp.brand_etl = cl2.brand_etl

union all

-- Dòng "âm" loại trừ chi phí túi ngực/túi mông — xem chú thích đầu file. ma_giao_dich tiền tố
-- "tuimong-" để không trùng ma_giao_dich với invoice thật (đang là invoiceid số nguyên dạng text).
select
    'Hồng Hà' as brand,
    'EHC' as nguon_he_thong,
    'tuimong-' || tnm.servicedataid::text as ma_giao_dich,
    false as co_chi_tiet_booking,
    tnm.servicedatadate::date as ngay,
    extract(year from tnm.servicedatadate)::int as nam,
    extract(month from tnm.servicedatadate)::int as thang,
    pr2.patientcode as ma_khach_hang,
    pr2.patientname as ten_khach_hang,
    null::text as ma_booking,
    'Vật tư túi ngực/túi mông (loại trừ)' as nhom_dich_vu,
    null::text as san_pham,
    'Hồng Hà' as chi_nhanh,
    null::text as nguon,
    null::text as nhom_nguon_khach,
    tnm.so_tien::numeric as so_tien
from tui_nguc_mong tnm
left join pr pr2 on pr2.patientrecordid = tnm.patientrecordid

union all

-- Dòng "âm" trừ lương bác sĩ PTTM theo ca ra viện — xem chú thích CTE luong_bs.
select
    'Hồng Hà' as brand,
    'EHC' as nguon_he_thong,
    'luongbs-' || lbs.loai_phau || '-' || lbs.patientrecordid::text as ma_giao_dich,
    false as co_chi_tiet_booking,
    pr3.medicalrecorddate_out::date as ngay,
    extract(year from pr3.medicalrecorddate_out)::int as nam,
    extract(month from pr3.medicalrecorddate_out)::int as thang,
    pr3.patientcode as ma_khach_hang,
    pr3.patientname as ten_khach_hang,
    null::text as ma_booking,
    'Lương bác sĩ PTTM (loại trừ)' as nhom_dich_vu,
    case lbs.loai_phau when 'dai' then 'Đại phẫu' else 'Tiểu phẫu' end as san_pham,
    'Hồng Hà' as chi_nhanh,
    null::text as nguon,
    null::text as nhom_nguon_khach,
    (case lbs.loai_phau when 'dai' then -2000000 else -500000 end)::numeric as so_tien
from luong_bs lbs
join {{ ref('stg_rtds_ehc_tb_patientrecord') }} pr3
  on pr3.patientrecordid = lbs.patientrecordid
 and pr3.dm_patientrecordstatusid = 1
 and pr3.medicalrecorddate_out >= date '2026-01-01'
