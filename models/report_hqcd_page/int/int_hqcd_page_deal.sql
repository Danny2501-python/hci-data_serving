-- =============================================================================
-- int_hqcd_page_deal
-- Stream: Deal Facebook (convert_type = 1, ticket_source like '%Facebook%')
-- Lấy nhóm dịch vụ qua custom_field id = 9794
-- =============================================================================

with psm as (
    select * from {{ ref('stg_hqcd_page_service_map') }}
    where map_scope = 'all'
),

pmap as (
    select * from {{ ref('stg_hqcd_product_ctg_map') }}
),

deal_fields_raw as (
    select
        cda.created_at                               as date,
        cda.requester_id                             as metric,
        cda.id                                       as ticket_id,
        psm.service_name,
        psm.page_id,
        cf_elem ->> 'id'                             as cf_id,
        cf_elem ->> 'value'                          as cf_value
    from {{ source('hqcd', 'cs_deal_detail_api_v2') }} cda
    left join psm on psm.service_id = cda.service_id
    cross join lateral jsonb_array_elements(cda.custom_fields::jsonb) cf_elem
    where cda.brand_id     = 1
      and cda.created_at  >= '2025-01-01'
      and cda.ticket_source like '%Facebook%'
      and cda.convert_type = 1
)

select
    d.date,
    d.metric,
    'deal'                                       as bang,
    d.service_name                               as page,
    d.ticket_id,
    0::numeric                                   as sub_mt,
    0                                            as "?column?",
    '@'                                          as email,
    'abc'                                        as bp,
    d.page_id,
    gkc.kdtc_product_ctg                         as dv_mb,
    trim(split_part(ccf.value_lable, ']', 2))   as dv_ht,
    null::text                                   as local,
    null::text                                   as vk
from deal_fields_raw d
left join {{ source('hqcd', 'cs_custom_fields') }} ccf
       on ccf.value_id = d.cf_value
left join pmap
       on upper(pmap.product_category) = upper(trim(split_part(ccf.value_lable, ']', 2)))
left join {{ source('hqcd', 'ggs_kdtc_product_ctg') }} gkc
       on gkc.kdtc_product_ctg_id = pmap.kdtc_product_ctg_id
where d.cf_id = '9794'
