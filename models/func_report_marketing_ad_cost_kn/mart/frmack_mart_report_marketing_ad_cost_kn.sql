select * from {{ ref('frmack_int_stg_mkt_fb_ads_final') }}
union all
select * from {{ ref('frmack_int_stg_mkt_non_cost_final') }}
