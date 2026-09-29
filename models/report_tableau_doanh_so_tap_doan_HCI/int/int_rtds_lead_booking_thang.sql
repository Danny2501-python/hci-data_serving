-- (2026-09-28) Chỉ số lead/booking theo tháng cho Kangnam/Paris — union vào report_rtds_doanh_so_thang
-- (bảng Tableau `report_doanh_so_thang_HCI`) thành DÒNG RIÊNG (tong_so_tien/so_giao_dich NULL), cùng
-- grain brand × năm × tháng × chi nhánh × nguồn × nhóm nguồn × MD/ML (nhom_dich_vu NULL vì 1 lead/booking
-- có nhiều dịch vụ). User chốt:
--   so_sdt_verify  = số lead (crm_lead.type = 'lead') có ≥1 crm_line (crm_line.crm_id = lead.id) — tháng theo create_date.
--   so_booking_tao / so_lich_hen_kh: (2026-09-29) ĐỔI sang logic workbook "Bộ chỉ số kinh doanh" — nguồn
--                    report_crm_lead_customer_out_sold, đếm MÃ KHÁCH (code_customer + brand), xem CTE os_booking/os_md.
--   ⚠⚠ (2026-09-29) User chốt: cả 3 chỉ số CHỈ TÍNH NGUỒN MD (nhom_md_ml = 'MD', kể cả dòng 'Tổng brand').
--   Lý do: khách ML (KH cũ/giới thiệu/MKT cơ sở) được chi nhánh tạo lead rồi chuyển booking ngay (< 5 phút),
--   KHÔNG nhập dịch vụ ở lead → "lead có crm_line" không phản ánh bước verify → phễu ML vô lý (verify < booking).
--   ⚠ new_product.crm_line chỉ có dòng write_date ≥ 2026-05-24 cho tới khi chạy backfill_crm_line_from_sandbox.py
--   → verify trước ~T6/2026 thiếu nếu chưa backfill.
-- (2026-09-28 tối) User chốt: [từ 2026-09-29 chỉ còn so_sdt_verify] ĐẾM THEO SỐ ĐIỆN THOẠI DUY NHẤT (crm_lead.phone), không
-- đếm theo id lead/booking. Chuẩn hoá nhẹ: bỏ ký tự không phải số, '84' + 9 số → '0' + 9 số; phone rỗng → bỏ
-- (~20 dòng/2026). Duy nhất TRONG từng dòng grain (brand × tháng × chi nhánh × nguồn × MD/ML) → SUM qua
-- nhiều chi nhánh/nguồn/tháng có thể đếm trùng 1 SĐT.
-- Ngày trong crm_lead lưu UTC → +7h trước khi lấy tháng (giống script out_sold: booking_date/create_on + 7h).
-- MD/ML: quy tắc KHÁCH HÀNG (rtds_nhom_md_ml_khach — cờ is_source_md, như khách đến cửa MD).
-- Lọc: active + loại như doanh số KPI (int_rtds_kangnam/paris): nguồn CBNV/đối ngoại/TPM/bác sĩ hợp tác,
-- 'All services'; Kangnam loại chi nhánh đóng cửa (closed_company_ids); Paris loại category nguồn
-- kpi_exclude_category_source_ids_paris. Chỉ từ năm 2026 (brand_etl crm_lead chỉ đáng tin từ ~T8/2025).

with lead_booking as (
    select
        l.id,
        l.brand_etl,
        l.type,
        l.source_id,
        l.company_id,
        nullif(
            regexp_replace(regexp_replace(coalesce(l.phone, ''), '[^0-9]', '', 'g'), '^84([0-9]{9})$', '0\1'),
            ''
        ) as sdt,
        l.create_date + interval '7 hours' as ngay_tao,
        l.booking_date + interval '7 hours' as ngay_hen
    from {{ ref('stg_rtds_crm_lead') }} l
    where l.brand_etl in (1, 3)
      and l.active
      and l.type in ('lead', 'opportunity')
      and nullif(regexp_replace(coalesce(l.phone, ''), '[^0-9]', '', 'g'), '') is not null
),

loc as (
    select
        lb.*,
        case lb.brand_etl when 1 then 'Kangnam' when 3 then 'Paris' end as brand,
        mrc.name as chi_nhanh,
        ss.source as nguon,
        ss.newcat_source as nhom_nguon_khach,
        {{ rtds_nhom_md_ml_khach('lb.source_id', 'ss.category_id', 'ss.source') }} as nhom_md_ml
    from lead_booking lb
    left join {{ ref('stg_rtds_m_res_company') }} mrc
        on mrc.id = lb.company_id and mrc.brand_etl = lb.brand_etl
    left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = lb.source_id
    where not (lb.brand_etl = 1 and coalesce(lb.company_id, 0) in ({{ var('closed_company_ids') | join(',') }}))
      and not (lb.brand_etl = 3 and coalesce(ss.category_id, 0) in ({{ var('kpi_exclude_category_source_ids_paris') | join(',') }}))
      and not (
        coalesce(lb.source_id, 0) in ({{ var('kpi_exclude_source_ids_cbnv') | join(',') }})
        or coalesce(ss.source ilike '%cbnv%', false)
      )
      and not (
        coalesce(lb.source_id, 0) in ({{ var('kpi_exclude_source_ids_doi_ngoai') | join(',') }})
        or coalesce(ss.source ilike '%đối ngoại%', false)
      )
      and not (
        coalesce(lb.source_id, 0) in ({{ var('kpi_exclude_source_ids_tpm') | join(',') }})
        or coalesce(ss.source ilike '%thuê phòng mổ%', false)
        or coalesce(ss.source ilike '%tpm%', false)
      )
      and not (
        lb.ngay_tao >= date '{{ var("kpi_exclude_bs_hop_tac_tu_ngay") }}'
        and (
          coalesce(lb.source_id, 0) in ({{ var('kpi_exclude_source_ids_bs_hop_tac') | join(',') }})
          or coalesce(ss.source ilike '%bác sĩ hợp tác%', false)
        )
      )
      and coalesce(ss.source, '') <> 'All services'
),

-- (2026-09-29) User chốt: so_lich_hen_kh = "Số KH có lịch hẹn" (booking hẹn lịch, cd_customer_appointment) của
-- workbook "KANGNAM - BỘ CHỈ SỐ KINH DOANH" bản MD; so_booking_tao = cùng tập booking nhưng tháng theo NGÀY TẠO
-- (create_on) trong out_sold. Đúng nhánh data_union = 'crm_lead' của Custom SQL workbook:
--   nguồn report_crm_lead_customer_out_sold, brand_id 1/3, DISTINCT ON (crm_id, brand_etl) ưu tiên total_received
--   lớn nhất rồi clineid; đếm COUNTD(code_customer + '_' + brand_id) (code_customer NULL → không đếm, như Tableau);
--   chi nhánh = report_company. Lịch hẹn: tháng theo report_date (= ngày đến cửa nếu đã đến, còn lại ngày hẹn —
--   đã +7h trong bảng), report_date < now(). Booking tạo: tháng theo create_on (đã +7h trong bảng).
--   Lọc MD = filter_indicator_show: is_kpi_branch (is_no_kpi / CBNV / đối ngoại / TPM / BS hợp tác từ
--   kpi_exclude_bs_hop_tac_tu_ngay) AND is_source_md AND label_type_schedule NOT IN ('4.guarantee' = type_crm_id 3,
--   '5.no_kpi' = amount_paid 0 và stage_id 4) AND NOT is_cosmetics (coalesce(view_stag_products.product_category,
--   'SAN PHAM') = 'SAN PHAM') AND source <> 'All services'. Paris thêm loại category kpi_exclude_category_source_ids_paris.
--   (Nhánh guarantee "reason_close_booking = 'tao_booking_bh' AND booking_id NOT NULL" bỏ qua: out_sold không có
--   booking_id. Nhánh no_kpi "KH cũ nhận quà" chỉ thuộc ML → không ảnh hưởng MD.)
os_booking as (
    select distinct on (crm_id, brand_etl)
        crm_id, brand_etl, brand_id, product_id, source_id, category_source_id, source,
        type_crm_id, amount_paid, stage_id, report_company, report_date, create_on,
        case when nullif(code_customer, '') is not null then code_customer || '_' || brand_id::text end as ma_khach
    from {{ ref('stg_rtds_report_crm_lead_customer_out_sold') }}
    where brand_id in (1, 3)
    order by crm_id, brand_etl, coalesce(total_received, 0) desc, clineid
),

os_md as (
    select
        case o.brand_id when 1 then 'Kangnam' when 3 then 'Paris' end as brand,
        o.report_company as chi_nhanh,
        o.source as nguon,
        ss.newcat_source as nhom_nguon_khach,
        'MD' as nhom_md_ml,
        o.report_date,
        o.create_on,
        o.ma_khach
    from os_booking o
    left join {{ ref('stg_rtds_view_stag_products') }} sp
        on sp.product_id = o.product_id and sp.brand_etl = o.brand_id
    left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = o.source_id
    where {{ rtds_nhom_md_ml_khach('o.source_id', 'o.category_source_id', 'o.source') }} = 'MD'
      and not coalesce(sp.is_no_kpi, false)
      and coalesce(sp.product_category, 'SAN PHAM') <> 'SAN PHAM'
      and coalesce(o.type_crm_id, 0) <> 3
      and not (coalesce(o.amount_paid, 0) = 0 and o.stage_id = 4)
      and coalesce(o.source, '') <> 'All services'
      and not (o.brand_id = 3 and coalesce(o.category_source_id, 0) in ({{ var('kpi_exclude_category_source_ids_paris') | join(',') }}))
      and not (
        coalesce(o.source_id, 0) in ({{ var('kpi_exclude_source_ids_cbnv') | join(',') }})
        or coalesce(o.source ilike '%cbnv%', false)
      )
      and not (
        coalesce(o.source_id, 0) in ({{ var('kpi_exclude_source_ids_doi_ngoai') | join(',') }})
        or coalesce(o.source ilike '%đối ngoại%', false)
      )
      and not (
        coalesce(o.source_id, 0) in ({{ var('kpi_exclude_source_ids_tpm') | join(',') }})
        or coalesce(o.source ilike '%thuê phòng mổ%', false)
        or coalesce(o.source ilike '%tpm%', false)
      )
      and not (
        o.report_date >= date '{{ var("kpi_exclude_bs_hop_tac_tu_ngay") }}'
        and (
          coalesce(o.source_id, 0) in ({{ var('kpi_exclude_source_ids_bs_hop_tac') | join(',') }})
          or coalesce(o.source ilike '%bác sĩ hợp tác%', false)
        )
      )
),

su_kien as (
    -- (2026-09-29) CHỈ nguồn MD cho cả 3 chỉ số (xem đầu file). Cột ma_dem: verify = SĐT; booking = mã khách.
    -- SĐT verify: lead MD có crm_line (crm_lead — giữ nguyên)
    select l.brand, l.chi_nhanh, l.nguon, l.nhom_nguon_khach, l.nhom_md_ml, l.ngay_tao as ngay,
           'verify' as loai, l.sdt as ma_dem
    from loc l
    where l.type = 'lead'
      and l.nhom_md_ml = 'MD'
      and exists (
          select 1 from {{ ref('stg_rtds_crm_line') }} c
          where c.crm_id = l.id and c.brand_etl = l.brand_etl
      )
    union all
    -- Booking tạo: out_sold theo ngày tạo (create_on)
    select brand, chi_nhanh, nguon, nhom_nguon_khach, nhom_md_ml, create_on, 'booking_tao', ma_khach
    from os_md
    where create_on is not null
    union all
    -- KH có lịch hẹn (booking hẹn lịch): out_sold theo report_date, chỉ tới hiện tại
    select brand, chi_nhanh, nguon, nhom_nguon_khach, nhom_md_ml, report_date, 'lich_hen', ma_khach
    from os_md
    where report_date is not null and report_date < now()
)

select
    brand,
    extract(year from ngay)::int as nam,
    extract(month from ngay)::int as thang,
    'CRM' as nguon_he_thong,
    chi_nhanh,
    cast(null as varchar) as nhom_dich_vu,
    nguon,
    nhom_nguon_khach,
    nhom_md_ml,
    count(distinct ma_dem) filter (where loai = 'verify') as so_sdt_verify,
    count(distinct ma_dem) filter (where loai = 'booking_tao') as so_booking_tao,
    count(distinct ma_dem) filter (where loai = 'lich_hen') as so_lich_hen_kh,
    null::bigint as so_sdt_verify_brand,
    null::bigint as so_booking_tao_brand,
    null::bigint as so_lich_hen_kh_brand
from su_kien
where extract(year from ngay) >= 2026
group by 1, 2, 3, 4, 5, 6, 7, 8, 9

union all

-- (2026-09-28) User chốt phương án (b): 1 dòng / brand × tháng, chi_nhanh = 'Tổng brand', chỉ có 3 cột *_brand
-- = SĐT (verify) / mã khách (booking) DUY NHẤT THẬT cả brand trong tháng (không đếm trùng qua chi nhánh/nguồn). Các cột
-- khác NULL → SUM(*_brand) trong Tableau không trùng, SUM(3 cột chi tiết) không đổi. ⚠ Cộng nhiều tháng vẫn
-- đếm trùng SĐT quay lại.
select
    brand,
    extract(year from ngay)::int as nam,
    extract(month from ngay)::int as thang,
    'CRM' as nguon_he_thong,
    'Tổng brand' as chi_nhanh,
    cast(null as varchar) as nhom_dich_vu,
    cast(null as varchar) as nguon,
    cast(null as varchar) as nhom_nguon_khach,
    cast(null as text) as nhom_md_ml,
    null::bigint as so_sdt_verify,
    null::bigint as so_booking_tao,
    null::bigint as so_lich_hen_kh,
    count(distinct ma_dem) filter (where loai = 'verify') as so_sdt_verify_brand,
    count(distinct ma_dem) filter (where loai = 'booking_tao') as so_booking_tao_brand,
    count(distinct ma_dem) filter (where loai = 'lich_hen') as so_lich_hen_kh_brand
from su_kien
where extract(year from ngay) >= 2026
group by 1, 2, 3
