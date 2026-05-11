{{ config(
    materialized='table',
    alias='report_operation_team_seeding_final'
) }}

WITH abc AS (
    SELECT DISTINCT ON (cdda.id)
        cdda.created_at,
        cdda.assignee,
        cdda.id::TEXT AS ticket_id,
        cdda.requester,
        cdda.requester_id,
        -- Các trường json đã replace
        (REPLACE(REPLACE(cdda.assignee, '''', '"'), 'None', 'null'))::JSONB ->> 'id'         AS assignee_id,
        (REPLACE(REPLACE(cdda.assignee, '''', '"'), 'None', 'null'))::JSONB ->> 'username'   AS assignee_username,
        (REPLACE(REPLACE(cdda.assignee, '''', '"'), 'None', 'null'))::JSONB ->> 'email'      AS assignee_email,
        (REPLACE(REPLACE(cdda.assignee, '''', '"'), 'None', 'null'))::JSONB ->> 'phone_no'   AS assignee_phone_no,
        (REPLACE(REPLACE(cdda.assignee, '''', '"'), 'None', 'null'))::JSONB ->> 'agent_id'   AS assignee_agent_id,
        (REPLACE(REPLACE(cdda.assignee, '''', '"'), 'None', 'null'))::JSONB ->> 'role_id'    AS assignee_role_id,
        (REPLACE(REPLACE(cdda.assignee, '''', '"'), 'None', 'null'))::JSONB ->> 'group_id'   AS assignee_group_id,
        (REPLACE(REPLACE(cdda.assignee, '''', '"'), 'None', 'null'))::JSONB ->> 'group_name' AS assignee_group_name
    FROM {{ source('frots', 'cs_deal_detail_api_v2') }} cdda
    WHERE cdda.assignee ~ '^\{.*\}$'
    ORDER BY cdda.id, cdda.updated_at DESC
)

SELECT
    rot.*,
    abc.assignee_id AS ticket_assignee_id,
    abc.assignee_username AS ticket_assignee_username,
    abc.assignee_email AS ticket_assignee_email,
    abc.assignee_group_name AS ticket_assignee_group_name,
    CASE
        WHEN "nhân viên" IS NULL AND "source" = 'MD - Affiliate' THEN 'Affiliate'
        ELSE "nhân viên"
    END AS employee
FROM {{ ref('mart_frots_operation_team_seeding') }} rot
LEFT JOIN abc ON rot.ticket_id = abc.ticket_id
WHERE "thương hiệu" <> 'Hồng Hà'
