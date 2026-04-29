-- =============================================================================
-- int_hqcd_page_lead
-- Stream: Lead (bang = 'lead') từ ds_unified, gắn page qua inbox ticket_id
-- =============================================================================

with
cline_data as (
    select * from {{ ref('stg_hqcd_mv_cline') }} where part_line in (1, 2, 3, 4)
),
ecl_kh as (
    select * from {{ ref('stg_hqcd_mv_ecl') }} where part in (1, 2, 3, 4)
),

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
    where mft.nguon       = 'MD - Facebook'
      and mft.bang in ('lkt', 'lnew')   -- chỉ lấy lead
),

lead_normalized as (
    select
        payment_date                                        as date,
        crm_id                                             as metric,
        'lead'                                             as bang,
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
    from lead_raw
),

inbox_ref as (
    select * from {{ ref('int_hqcd_page_inbox') }}
)

select
    ln.date,
    ln.metric,
    ln.bang,
    ibx.page,
    ln.ticket_id,
    ln.sub_mt,
    0                                                      as "?column?",
    ln.email,
    ln.bp,
    ibx.page_id,
    ln.dv_mb,
    ln.dv_ht,
    ln.local,
    ln.vk,
    row_number() over (partition by ln.metric order by ln.metric) as rnk
from lead_normalized ln
left join inbox_ref ibx on ibx.ticket_id = ln.ticket_id
