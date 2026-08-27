{{
  config(
    materialized = 'table'
  )
}}
-- =============================================================================
-- int_rhp_page_inbox
-- Stream: Inbox Facebook (cs_ticket_api)
-- Dedup theo ticket_id, gắn page qua service_id
-- =============================================================================

with psm as (
    select * from {{ ref('stg_rhp_page_service_map') }}
    where map_scope = 'all'
),

inbox_deduped as (
    select created_at, requester_id, ticket_id, service_id
    from (
        select
            cta.created_at,
            cta.requester_id,
            cta.ticket_id,
            cta.service_id,
            row_number() over (partition by cta.ticket_id order by cta.ticket_id) as rn
        from {{ source('rhp', 'cs_ticket_api') }} cta
        where cta.brand_id    = 1
          and cta.created_at >= '2025-01-01'
          and cta.ticket_source in ('Inbox Facebook', 'Inbox Facebook Out')
    ) t
    where rn = 1
),

inbox_with_page as (
    select
        itd.created_at,
        itd.requester_id,
        itd.ticket_id,
        psm.service_name,
        psm.page_id
    from inbox_deduped itd
    left join psm on psm.service_id = itd.service_id
)

select
    date(created_at)   as date,
    requester_id       as metric,
    'inbox'            as bang,
    service_name       as page,
    ticket_id,
    0::numeric         as sub_mt,
    0                  as "?column?",
    '@'                as email,
    'abc'              as bp,
    page_id,
    null::text         as dv_mb,
    null::text         as dv_ht,
    null::text         as local,
    null::text         as vk
from inbox_with_page

