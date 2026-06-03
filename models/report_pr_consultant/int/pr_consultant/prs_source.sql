select 
        ss.old_id,
		ss."source" ,
		ss.category_source ,
		ss.channel ,
		ss.category_channel,
		ss.newcat_source ,
		ss2.org_source ,
		ss2.category_source category_source_ss
from {{ source('prs_raw_data', 'stag_sources') }} ss 
left join {{ source('prs_raw_data', 'stag_sources') }}  ss2 on ss.id_pr = ss2.old_id


