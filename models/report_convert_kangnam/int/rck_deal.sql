--- deal có người convert duy nhất

with deal as (
    select
        id,
        requester_id,
        convert_at,
        ticket_source,
        convert_by,
        created_at,
        row_number() over (partition by id) as no_deal
    from {{ source('rck_base', 'cs_deal_detail_api_v2') }}
)

select
    d.id,
    d.created_at,
    d.requester_id,
    d.convert_by,
    a.username as convert_by1,
    a.group_name as group_name_convert,
    d.convert_at
from deal d
left join {{ source('rck_base', 'cs_agents_api') }} a on a.id = d.convert_by
where d.convert_by <> 0
and d.convert_by is not null
and d.no_deal = 1
