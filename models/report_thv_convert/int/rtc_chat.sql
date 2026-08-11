---Bảng chat, lấy thời gian chat đầu tiên của ticket
--- nhân viên tiếp nhận chat đầu tiên của mỗi ticket

with chat as (
    select
        ticket_id,
        conversation_id,
        start_time,
        agent_email,
        agent_name,
        group_name,
        row_number() over (partition by ticket_id order by start_time, conversation_id) as no_conver
    from {{ source('rtc_base', 'cs_chat_api_thv') }}
    where date(start_time) >= '{{ var("start_date") }}'::date
)

select
    ticket_id,
    conversation_id,
    start_time,
    agent_email,
    agent_name,
    group_name
from chat
where no_conver = 1