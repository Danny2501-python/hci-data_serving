-- =============================================================================
-- int_hqcd_page_ds
-- Stream: Doanh số + Lead gắn page (qua inbox ticket_id)
-- Phân bổ DS chưa có page theo tỷ trọng (khớp logic gốc rate < 1)
-- =============================================================================

with
-- Partitioned view helpers
cline_ds as (
    select * from {{ ref('stg_hqcd_mv_cline') }} where part_line in (1, 3, 5, 6)
),
cline_data as (
    select * from {{ ref('stg_hqcd_mv_cline') }} where part_line in (1, 2, 3, 4)
),
ecl_kh as (
    select * from {{ ref('stg_hqcd_mv_ecl') }} where part in (1, 2, 3, 4)
),
ecl_ds as (
    select * from {{ ref('stg_hqcd_mv_ecl') }} where part in (1, 3, 5, 6)
),

-- Thanh toán thực tế (Payment → bang = 'ds')
payment_raw as (
    select
        spt.payment_date,
        spt.crm_id,
        spt.payment                      as sub_mt,
        'payment'                        as bang,
        mrc.name                         as chi_nhanh,
        mrc.id                           as company_id,
        sp.product_category              as dv_ht,
        gpc.kdtc_product_ctg             as dv_mb,
        gpc.kdtc_service_type,
        cl.overseas_vietnamese,
        cl.ticket_id,
        se.login                         as work_email
    from (select * from {{ source('hqcd', 'stag_payment_transfer') }} where brand_etl in (0, 1)) spt
    left join {{ source('hqcd', 'm_res_company') }}        mrc on mrc.id = spt.company_id
                                                               and mrc.brand_id  = 1
                                                               and mrc.brand_etl = 1
    left join ecl_ds                                        cl  on cl.id  = spt.crm_id
    left join {{ source('hqcd', 'stag_sources') }}          ss  on ss.old_id = cl.source_id
    left join cline_ds                                      cl2 on cl2.id = spt.clineid
    left join {{ source('hqcd', 'stag_products') }}         sp  on sp.product_id = cl2.product_id
    left join {{ source('hqcd', 'ggs_kdtc_product_ctg') }}  gpc on gpc.kdtc_product_ctg_id = sp.kdtc_product_ctg_id
    left join {{ source('hqcd', 'res_users') }}             se  on se.id = cl.create_by and se.brand_etl = 1
    where mrc.brand_id        = 1
      and spt.product_type   <> 'cosmetic'
      and ss.source           = 'MD - Facebook'
      and spt.payment_date   >= '2025-08-01'
),

-- Lead doanh số từ T8/2025 (bang 'lkt'/'lnew' → lead, khác → ds)
lead_raw as (
    select
        mft.ngay_tao             as payment_date,
        mft.id                   as crm_id,
        mft.cp                   as sub_mt,
        mft.bang,
        mft.chi_nhanh,
        mft.company_id,
        sp.product_category      as dv_ht,
        gpc.kdtc_product_ctg     as dv_mb,
        gpc.kdtc_service_type,
        dkh.overseas_vietnamese,
        dkh.ticket_id,
        mft.work_email
    from {{ ref('stg_hqcd_mv_lead_mb') }}         mft
    left join {{ source('hqcd', 'ggs_kdtc_product_ctg') }}  gpc  on gpc.kdtc_product_ctg_id = mft.nhom_dv_id
    left join ecl_kh                                         dkh  on dkh.id = mft.id
    left join cline_data                                     cd   on cd.crm_id = mft.id
    left join {{ source('hqcd', 'stag_products') }}          sp   on sp.product_id = cd.product_id
    where mft.nguon = 'MD - Facebook'
),

-- Union payment + lead
ds_unified as (
    select
        payment_date, crm_id, sub_mt,
        'ds'  as bang,
        chi_nhanh, company_id, dv_ht, dv_mb, kdtc_service_type,
        overseas_vietnamese, ticket_id, work_email
    from payment_raw

    union all

    select
        payment_date, crm_id, sub_mt,
        case when bang in ('lkt', 'lnew') then 'lead' else 'ds' end as bang,
        chi_nhanh, company_id, dv_ht, dv_mb, kdtc_service_type,
        overseas_vietnamese, ticket_id, work_email
    from lead_raw
),

-- Chuẩn hóa local + vk
ds_normalized as (
    select
        payment_date                                        as date,
        crm_id                                             as metric,
        bang,
        ticket_id,
        sub_mt,
        '@'                                                as email,
        'abc'                                              as bp,
        dv_mb,
        dv_ht,
        case when company_id in (4, 12) then 'HỒ CHÍ MINH'
             else chi_nhanh
        end                                                as local,
        case when overseas_vietnamese = 'marketing' then 'International'
             else 'Domestic'
        end                                                as vk
    from ds_unified
),

-- Inbox with page (dùng để gắn page_id vào DS qua ticket)
inbox_ref as (
    select * from {{ ref('int_hqcd_page_inbox') }}
),

-- Gắn page_id qua inbox ticket_id
ds_with_page as (
    select
        dsn.date,
        dsn.metric,
        dsn.bang,
        ibx.page    as service_name,
        dsn.ticket_id,
        dsn.sub_mt,
        dsn.email,
        dsn.bp,
        ibx.page_id,
        dsn.dv_mb,
        dsn.dv_ht,
        dsn.local,
        dsn.vk
    from ds_normalized dsn
    left join inbox_ref ibx on ibx.ticket_id = dsn.ticket_id
),

-- Tỷ lệ DS theo page (khớp logic gốc: chỉ page có ds_page > 1)
page_ds_by_page as (
    select page_id, sum(sub_mt) as ds_page
    from ds_with_page
    where page_id is not null and bang = 'ds'
    group by page_id
),

page_rate as (
    select
        p.page_id,
        p.ds_page,
        t.ds_total,
        p.ds_page / t.ds_total as rate
    from page_ds_by_page p
    cross join (
        select sum(sub_mt) as ds_total
        from ds_with_page
        where page_id is not null and bang = 'ds'
    ) t
    where p.ds_page > 1
),

-- Phân bổ DS chưa gắn được page (join rate < 1 — khớp gốc)
ds_allocated as (
    select
        dwp.date, dwp.metric, dwp.bang,
        psm.service_name,
        dwp.ticket_id,
        dwp.sub_mt * pr.rate    as sub_mt,
        dwp.email, dwp.bp,
        pr.page_id,
        dwp.dv_mb, dwp.dv_ht, dwp.local, dwp.vk
    from ds_with_page dwp
    left join page_rate pr on pr.rate < 1
    left join {{ ref('stg_hqcd_page_service_map') }} psm
           on text(psm.page_id) = text(pr.page_id)
           and psm.map_scope = 'inbox'
    where dwp.service_name is null
      and dwp.bang = 'ds'
)

-- DS có page (gắn được qua ticket)
select date, metric, bang, service_name as page, ticket_id,
       sub_mt, 0 as "?column?", email, bp, page_id, dv_mb, dv_ht, local, vk
from ds_with_page
where bang = 'ds' and page_id is not null

union all

-- DS phân bổ theo tỷ trọng
select date, metric, bang, service_name as page, ticket_id,
       sub_mt, 0 as "?column?", email, bp, page_id, dv_mb, dv_ht, local, vk
from ds_allocated
