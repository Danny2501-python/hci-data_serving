with chat_api_raw as (
    select 
        ticket_id, 
        facebook_page_id
    from {{ source('kangnam_source', 'cs_chat_api') }}
    group by 
        ticket_id, 
        facebook_page_id
),

pages as (
    select * from {{ source('kangnam_source', 'm_facebook_page_kangnam') }}
)

select
    c.ticket_id,
    p."tên" as page_name
from chat_api_raw c
left join pages p on p.id = c.facebook_page_id
