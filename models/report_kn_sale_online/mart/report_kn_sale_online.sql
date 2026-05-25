	with a as (
		select * from {{ref('stg_kso_lead')}}
	union all select * from {{ref('stg_kso_bk')}} 
	union all select * from {{ref('stg_kso_hl')}}
	 union all select * from {{ref('stg_kso_dc')}}
		union all select * from {{ref('stg_kso_tc')}}
	 union all 
	 select * from {{ref('stg_kso_ds')}} where ma_phieu is not null
	)
	select * from a--- where nhom_dv <> 'SAN PHAM'