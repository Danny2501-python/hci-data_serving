{{
  config(
    materialized = 'table',
    alias        = 'stg_hqcd_mv_lead_mb'
  )
}}
-- =============================================================================
-- stg_hqcd_mv_lead_mb  (thay thế MATERIALIZED VIEW public.mv_lead_mb_from_t8_2025)
-- Lead brand mới từ T8/2025, xác định chi phí dự kiến qua bảng rate
-- Output columns: bang, id, l_name, ngay_tao, type_tc, id_tc, b_name,
--                 phone, work_email, nguon, chi_nhanh, nhom_dv_id,
--                 company_id, percent_total_discount, ch, cp, product
-- =============================================================================

with

-- [a] Lead brand mới (1) từ T8/2025
a1 as (
    select
        cl.id,
        cl.name                                                   as l_name,
        cl.create_date,
        cl.phone,
        cl.create_by,
        cl.company_id,
        cl.source_id,
        lag(cl.id) over (partition by cl.phone order by cl.id)   as rnk,
        cl.type,
        cl.brand_etl
    from {{ source('hqcd', 'crm_lead') }} cl
    where cl.brand_etl = 1
),
a as (
    select * from a1
    where date(create_date) >= '2025-08-01'
),

-- [b] Dữ liệu ECL brand mới (dùng để join booking / lead cũ)
ecl_data as (
    select id, name, type, type_crm_id, brand_id, lead_id, ticket_id,
           overseas_vietnamese, arrival_date, amount_paid, create_date, phone,
           company_id, source_id, create_by, create_by_department, brand_etl
    from {{ source('hqcd', 'crm_lead') }}
    where brand_etl = 1
),

-- [c] crm_line brand mới
cline as (
    select id, crm_id, product_id, create_date, brand_etl,
           percent_total_discount
    from {{ source('hqcd', 'crm_line') }}
    where brand_etl = 1
),

-- [d] Xác định lead cũ có tham chiếu (booking/lead trong lịch sử)
old_data as (
    select
        a.id, a.l_name, a.create_date, a.phone, a.create_by,
        a.company_id, a.source_id, a.rnk, a.type, a.brand_etl,
        clb.create_date  as ngay_tao_b,
        clb.name         as b_name,
        clb.arrival_date,
        cll.id           as l_id,
        cll.create_date  as l_date,
        clb.create_date  as bk_date,
        clb.arrival_date as bdc_date,
        case
            when clb.name  is not null then 'book'
            when cll.id    is not null then 'lead'
            else 'new_data'
        end              as type_tc,
        clb.id           as b_id,
        clb.amount_paid  as paid_tc
    from a
    left join ecl_data clb
           on clb.lead_id = a.rnk and a.rnk is not null and clb.type_crm_id = 2
              and clb.brand_id = 1
    left join ecl_data cll
           on cll.id = a.rnk and a.rnk is not null
              and cll.brand_id = 1 and cll.type = 'lead'
    where a.rnk is not null and a.type = 'lead'
),

-- [e] Enrich old_data với chi nhánh, nguồn, email
data_l as (
    select
        o.id, o.type_tc, o.l_name, o.create_date, o.rnk as id_tham_chieu,
        case when o.type_tc = 'book'     then o.b_id
             when o.type_tc = 'lead'     then o.l_id
             when o.type_tc = 'new_data' then 0
        end                              as id_tc,
        o.b_name, o.phone, o.paid_tc,
        greatest(o.l_date, o.bk_date, o.bdc_date) as max_range,
        se.login                         as work_email,
        ss.source                        as nguon,
        mrc.name                         as chi_nhanh,
        mrc.id                           as company_id
    from old_data o
    left join {{ source('hqcd', 'm_res_company') }} mrc
           on mrc.id = o.company_id and mrc.brand_etl = 1
    left join {{ source('hqcd', 'res_users') }}     se
           on se.id = o.create_by and se.brand_etl = 1
    left join {{ source('hqcd', 'stag_sources') }}  ss
           on ss.old_id = o.source_id::double precision
),

-- [f] Lọc lead có khoảng cách > 30 ngày so với max_range
lead_prep as (
    select * from data_l
    where (date(create_date) - date(max_range)) > 30
      and nguon ilike '%MD%'
      and nguon not ilike '%Cơ sở%'
),

-- [g] Lần thanh toán gần nhất theo crm_id (để tính range_payment)
pay as (
    select
        spt.payment_date,
        cl.phone,
        spt.crm_id,
        row_number() over (partition by spt.crm_id order by spt.payment_date desc) as rnk
    from {{ source('hqcd', 'stag_payment_transfer') }} spt
    left join {{ source('hqcd', 'm_res_company') }}    mrc
           on mrc.id = spt.company_id
    left join ecl_data cl on cl.id = spt.crm_id
    where spt.brand_etl in (0, 1)
      and mrc.brand_id = 1
      and cl.amount_paid > 0
),

-- [h] Lọc lead cách lần thanh toán gần nhất > 30 ngày
lead_f as (
    select
        lp.*,
        p.payment_date,
        p.rnk,
        row_number() over (partition by lp.phone order by p.payment_date desc) as rank,
        date(lp.create_date) - p.payment_date as range_payment
    from lead_prep lp
    left join pay p on p.phone::text = lp.phone::text and lp.id > p.crm_id
    where (date(lp.create_date) - p.payment_date) > 30 and p.rnk = 1
       or p.phone is null
),

-- [i] Gắn nhóm dịch vụ ưu tiên theo đơn giá cao nhất
lpm as (
    select
        l.*,
        row_number() over (
            partition by cl.crm_id order by sp.list_price desc, cl.id
        )                                          as rnk_dv,
        sp.kdtc_product_ctg_id                     as nhom_dv_id,
        sp.product,
        cl.percent_total_discount
    from lead_f l
    left join cline cl on cl.crm_id = l.id
    left join {{ source('hqcd', 'stag_products') }} sp
           on sp.product_id = cl.product_id
    where l.rank = 1
),

-- [j1] Lead hoàn toàn mới (chưa có rnk = chưa có lịch sử)
lead_fr1 as (
    select
        'lnew'   as bang,
        a.id,
        a.l_name,
        a.create_date,
        'new_data' as type_tc,
        0          as id_tc,
        'abc'      as b_name,
        a.phone,
        se.login   as work_email,
        ss.source  as nguon,
        mrc.name   as chi_nhanh,
        row_number() over (partition by a.phone order by sp.list_price desc, cl.id) as rnk,
        sp.kdtc_product_ctg_id as nhom_dv_id,
        mrc.id     as company_id,
        cl.percent_total_discount,
        sp.product
    from a
    left join {{ source('hqcd', 'res_users') }}     se
           on se.id = a.create_by and se.brand_etl = 1
    left join {{ source('hqcd', 'stag_sources') }}  ss
           on ss.old_id = a.source_id::double precision and ss.brand_id = 1
    left join {{ source('hqcd', 'm_res_company') }} mrc
           on mrc.id = a.company_id and mrc.brand_etl = 1
    left join cline cl on cl.crm_id = a.id
    left join {{ source('hqcd', 'stag_products') }} sp
           on sp.product_id = cl.product_id
    where a.rnk is null
      and ss.source ilike '%MD%'
      and ss.source not ilike '%Cơ sở%'
      and a.create_date >= '2025-01-01'
      and a.type = 'lead'
),

-- [j2] Dedup lead mới
lead_fr as (
    select bang, id, l_name, create_date as ngay_tao, type_tc, id_tc, b_name,
           phone, work_email, nguon, chi_nhanh, nhom_dv_id, company_id,
           product, percent_total_discount
    from lead_fr1
    where rnk = 1
),

-- [k] Union lead mới + lead có tham chiếu cũ (lkt)
lead_rp as (
    select bang, id, l_name, ngay_tao, type_tc, id_tc, b_name, phone,
           work_email, nguon, chi_nhanh, nhom_dv_id, company_id,
           product, percent_total_discount
    from lead_fr

    union all

    select 'lkt' as bang, l.id, l.l_name, l.create_date as ngay_tao,
           l.type_tc, l.id_tham_chieu as id_tc, l.b_name, l.phone,
           l.work_email, l.nguon, l.chi_nhanh, l.nhom_dv_id, l.company_id,
           l.product, l.percent_total_discount
    from lpm l
    where l.rnk_dv = 1
),

-- [l] Gắn cờ ch = 1 (loại cơ hội)
data_r as (
    select *, 1 as ch from lead_rp
),

-- [m] Tính chi phí dự kiến qua bảng rate
data_report as (
    select
        dr.bang, dr.id, dr.l_name, dr.ngay_tao, dr.type_tc, dr.id_tc,
        dr.b_name, dr.phone, dr.work_email, dr.nguon, dr.chi_nhanh,
        dr.nhom_dv_id, dr.company_id, dr.percent_total_discount, dr.ch,
        gtr.cost_avg_mkt * gkc.mkt_rate as cp,
        dr.product
    from data_r dr
    left join {{ source('hqcd', 'ggs_kdtc_product_ctg_rate') }} gkc
           on gkc.company_id = dr.company_id::numeric
           and gkc.loai_co_hoi = dr.ch::numeric
           and gkc.kdtc_product_ctg_id = dr.nhom_dv_id::numeric
    left join {{ source('hqcd', 'ggs_kdtc_service_type_revenue') }} gtr
           on gtr.company_id = gkc.company_id
           and gtr.kdtc_service_type = gkc.kdtc_service_type
           and gtr.loai_co_hoi = gkc.loai_co_hoi
    where gtr.cost_avg_mkt is not null
      and gkc.mkt_rate      is not null
)

select * from data_report
