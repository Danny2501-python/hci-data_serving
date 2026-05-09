-- =============================================================================
-- stg_rhp_page_service_map
-- Mapping service_id → page_id từ cs_services_api
-- Giữ 2 dạng:
--   • map_all : tất cả service_type (dùng cho deal & inbox join)
--   • map_inbox: chỉ 'Inbox Facebook', dedup by page_id (dùng cho DS allocation)
-- =============================================================================

with map_all as (
    select
        service_type,
        service_id,
        service_name,
        split_part(detail, '''', 4) as page_id
    from {{ source('rhp', 'cs_services_api') }}
    where detail   is not null
      and brand_id = 1
),

map_inbox as (
    select service_type, service_id, service_name, page_id
    from (
        select *,
               row_number() over (partition by page_id) as rn
        from   map_all
        where  service_type = 'Inbox Facebook'
    ) t
    where rn = 1
)

select
    'all'   as map_scope,
    service_type, service_id, service_name, page_id
from map_all

union all

select
    'inbox' as map_scope,
    service_type, service_id, service_name, page_id
from map_inbox

