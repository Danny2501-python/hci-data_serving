select
			ticket_id,
			mfpk.tên
		from
			(
			select
				ticket_id,
				facebook_page_id
			from
				cs_chat_api
			group by
				ticket_id,
				facebook_page_id)cca
		left join {{source('kso_crm_base','m_facebook_page_kangnam')}} mfpk on
			mfpk.id = cca.facebook_page_id	