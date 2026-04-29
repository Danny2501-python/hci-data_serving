-- =============================================================================
-- int_hqcd_page_cost
-- Stream: Chi phí Facebook (Cost_fb_cd)
-- Nguồn: report_marketing_ad_cost_kn_v2
-- =============================================================================

with pmap as (
    select * from {{ ref('stg_hqcd_product_ctg_map') }}
)

select
    a.date                                                  as date,
    a."Metric"::numeric                                     as metric,
    'chi_phi_fb'                                            as bang,
    a.page                                                  as page,
    0::bigint                                               as ticket_id,
    0::numeric                                              as sub_mt,
    0                                                       as "?column?",
    '@'                                                     as email,
    'abc'                                                   as bp,
    a.page_id,
    coalesce(gkc.kdtc_product_ctg, a.nhom_dv)              as dv_mb,
    a.nhom_dv                                               as dv_ht,
    a.chi_nhanh                                             as local,
    case
        when upper(a.chi_nhanh) in ('VIỆT KIỀU', 'QUỐC TẾ') then 'International'
        else 'Domestic'
    end                                                     as vk
from {{ source('hqcd', 'report_marketing_ad_cost_kn_v2') }} a
left join pmap                 on upper(a.nhom_dv) = pmap.product_category
left join {{ source('hqcd', 'ggs_kdtc_product_ctg') }} gkc
       on gkc.kdtc_product_ctg_id = pmap.kdtc_product_ctg_id
where a.type_data = 'Cost_fb_cd'
