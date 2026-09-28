-- (2026-09-28) Chỉ số lead/booking theo tháng cho Kangnam/Paris — union vào report_rtds_doanh_so_thang
-- (bảng Tableau `report_doanh_so_thang_HCI`) thành DÒNG RIÊNG (tong_so_tien/so_giao_dich NULL), cùng
-- grain brand × năm × tháng × chi nhánh × nguồn × nhóm nguồn × MD/ML (nhom_dich_vu NULL vì 1 lead/booking
-- có nhiều dịch vụ). User chốt:
--   so_sdt_verify  = số lead (crm_lead.type = 'lead') có ≥1 crm_line (crm_line.crm_id = lead.id), CHỈ nguồn
--                    MD — tháng theo ngày tạo lead (create_date).
--   so_booking_tao = số booking (type = 'opportunity') theo create_date — mọi nguồn, tách MD/ML.
--   so_lich_hen_kh = số booking (type = 'opportunity') theo booking_date — mọi nguồn, tách MD/ML.
-- (2026-09-28 tối) User chốt: cả 3 chỉ số ĐẾM THEO SỐ ĐIỆN THOẠI KHÁCH HÀNG DUY NHẤT (crm_lead.phone), không
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

su_kien as (
    -- SĐT verify: lead nguồn MD có crm_line
    select l.brand, l.chi_nhanh, l.nguon, l.nhom_nguon_khach, l.nhom_md_ml, l.ngay_tao as ngay,
           'verify' as loai, l.sdt
    from loc l
    where l.type = 'lead'
      and l.nhom_md_ml = 'MD'
      and exists (
          select 1 from {{ ref('stg_rtds_crm_line') }} c
          where c.crm_id = l.id and c.brand_etl = l.brand_etl
      )
    union all
    -- Booking tạo: theo ngày tạo booking
    select brand, chi_nhanh, nguon, nhom_nguon_khach, nhom_md_ml, ngay_tao, 'booking_tao', sdt
    from loc
    where type = 'opportunity'
    union all
    -- Lịch hẹn KH: theo ngày hẹn (booking_date)
    select brand, chi_nhanh, nguon, nhom_nguon_khach, nhom_md_ml, ngay_hen, 'lich_hen', sdt
    from loc
    where type = 'opportunity' and ngay_hen is not null
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
    count(distinct sdt) filter (where loai = 'verify') as so_sdt_verify,
    count(distinct sdt) filter (where loai = 'booking_tao') as so_booking_tao,
    count(distinct sdt) filter (where loai = 'lich_hen') as so_lich_hen_kh
from su_kien
where extract(year from ngay) >= 2026
group by 1, 2, 3, 4, 5, 6, 7, 8, 9
