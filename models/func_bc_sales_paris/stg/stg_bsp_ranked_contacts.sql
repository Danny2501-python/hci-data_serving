-- =============================================================================
-- stg_bsp_ranked_contacts  (Pass 1)
-- Lấy thông tin khách hàng từ Caresoft Inbox Facebook.
-- Mỗi khách (cca.id) lấy ticket Inbox FB đầu tiên theo created_at,
-- sau đó lấy cuộc hội thoại đầu tiên có group_name theo start_time.
-- rank dùng để lọc rank=1 ở tầng int (int_bsp_inbox).
-- =============================================================================
WITH first_ticket AS (
    SELECT
        ad_id_value,
        requester_id,
        ticket_id,
        ticket_source,
        ROW_NUMBER() OVER (PARTITION BY requester_id ORDER BY created_at) AS rank
    FROM {{ source('paris', 'cs_ticket_api') }}
    WHERE ticket_source = 'Inbox Facebook'
      AND created_at > '2022-01-01'
),
first_chat AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY start_time ASC) AS rnk
    FROM {{ source('paris', 'cs_chat_api') }}
    WHERE group_name IS NOT NULL
)
SELECT
    DATE(cca.created_at)                                               AS ngay_tao_khach,
    cca.id                                                             AS khach_id,
    cca2.facebook_page_id                                              AS page,
    cca2.agent_name                                                    AS nv,
    cca2.agent_email                                                   AS mail_nv,
    cca2.ticket_id                                                     AS ticket,
    cca2.facebook_page_id                                              AS page_fb,
    t.ad_id_value                                                      AS ad_id,
    t.ticket_source                                                    AS nguon,
    ROW_NUMBER() OVER (PARTITION BY cca.id ORDER BY cca2.conversation_id) AS rank,
    cca.username
FROM {{ source('paris', 'cs_contact_api') }} cca
LEFT JOIN first_ticket t
       ON t.requester_id = cca.id AND t.rank = 1
LEFT JOIN first_chat cca2
       ON cca2.customer_id = t.requester_id AND cca2.rnk = 1
WHERE cca.brand_id = 3
  AND DATE(cca.created_at) > '2022-01-01'
  AND cca2.facebook_page_id <> ' '
