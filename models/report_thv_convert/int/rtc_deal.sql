--- tách thông tin người được gán (assignee) từ cột json assignee trên cs_deal_detail_api_v2_thv

select
    id,
    requester_id,
    ticket_source,
    created_at,
    convert_by,
    convert_at,
    assignee_id,
    (nullif(assignee, '')::jsonb ->> 'id')::numeric as assignee_user_id,
    nullif(assignee, '')::jsonb ->> 'username' as assignee_username,
    nullif(assignee, '')::jsonb ->> 'email' as assignee_email,
    nullif(assignee, '')::jsonb ->> 'phone_no' as assignee_phone,
    nullif(assignee, '')::jsonb ->> 'agent_id' as assignee_agent_id,
    (nullif(assignee, '')::jsonb ->> 'role_id')::integer as assignee_role_id,
    (nullif(assignee, '')::jsonb ->> 'group_id')::integer as assignee_group_id,
    nullif(assignee, '')::jsonb ->> 'group_name' as assignee_group_name
from {{ source('rtc_base', 'cs_deal_detail_api_v2_thv') }}
