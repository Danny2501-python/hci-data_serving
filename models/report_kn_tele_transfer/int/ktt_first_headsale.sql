SELECT DISTINCT ON (c.ticket_id)
           c.ticket_id,
           c.commentator_id AS first_user_id,
           date(c.created_at)     AS first_date,
           a.username,
           a.email,
        a.group_name
          --- dp.page_name
    FROM {{source('data','cs_deal_api_trans_comments')}} c
    ----join page p on p.ticket_id = c.ticket_id 
    ----join dim_page dp on dp.page_id = p.facebook_page_id
    left JOIN {{source('data','cs_agents_api')}} a
   --- join cs_contact_api cca on cca.
      ON c.commentator_id = a.id
    WHERE a.group_name ilike ('%head%') 
    ORDER BY c.ticket_id, c.created_at