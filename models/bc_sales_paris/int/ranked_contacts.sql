-- Pass 1: Rank contact/ticket
WITH ranked_contacts AS (
    select
        date(cca.created_at) as ngay_tao_khach,
        cca.id as khach_id,
        cca2.facebook_page_id as page,
        cca2.agent_name as nv,
        cca2.agent_email as mail_nv,
        cca2.ticket_id as ticket,
        cca2.facebook_page_id as page_fb,
        c.ad_id_value as ad_id,
        c.ticket_source as nguon,
        row_number() over(partition by cca.id order by cca2.conversation_id) as rank,
        cca.username
    from {{ source('paris_raw', 'cs_contact_api') }} cca
    left join 
    ( with a as(
        select
            ad_id_value,
            requester_id,
            ticket_id,
            ticket_source,
            row_number() over(partition by requester_id order by created_at ) as rank,
            created_at
        from {{ source('paris_raw', 'cs_ticket_api') }} cta )
        select
            a.ticket_source,
            a.ad_id_value,
            a.requester_id,
            a.ticket_id
        from a
        where
            a.rank = 1
            and ticket_source = 'Inbox Facebook'
            and created_at > '2022-01-01' ) c on c.requester_id = cca.id
        left join {{ source('paris_raw', 'cs_chat_api') }} cca2 on cca2.customer_id = c.requester_id
        where
            cca.brand_id = 3
            and date(cca.created_at) > '2022-01-01'
            and cca2.facebook_page_id <> ' '
)

SELECT * FROM ranked_contacts
