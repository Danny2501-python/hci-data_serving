		select * from {{ref('stg_kso_lead')}}
	union all select * from {{ref('stg_kso_bk')}} 
	union all select * from {{ref('stg_kso_hl')}}
	 union all select * from {{ref('stg_kso_dc')}}
		union all select * from {{ref('stg_kso_tc')}}
	 union all select * from {{ref('stg_kso_ds')}} 