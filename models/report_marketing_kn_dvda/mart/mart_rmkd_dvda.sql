{{
  config(
    materialized = 'table',
    alias        = 'report_marketing_kn_dvda'
  )
}}
-- =============================================================================
-- mart_report_marketing_kn_dvda
-- Union 8 streams: DC, DS, Lead, Inbox, TC, CFB, BK, HL
-- + re_map (tinh_noi) + region join
-- =============================================================================

with report as (
    select * from {{ ref('int_rmkd_dc') }}
    union all
    select * from {{ ref('int_rmkd_ds') }}
    union all
    select * from {{ ref('int_rmkd_lead') }}
    union all
    select * from {{ ref('int_rmkd_inbox') }}
    union all
    select * from {{ ref('int_rmkd_tc') }}
    union all
    select * from {{ ref('int_rmkd_cfb') }}
    union all
    select * from {{ ref('int_rmkd_bk') }}
    union all
    select * from {{ ref('int_rmkd_hl') }}
),

re_map as (
    select *,
        case when local_k ilike '%thành phố%' then regexp_replace(local_k, '^Thành phố\s*', '')
             when local_k ilike '%tỉnh%'      then regexp_replace(local_k, '^Tỉnh\s*', '')
             when local_k like '%Bà Rịa%'     then 'Bà Rịa – Vũng Tàu'
             when local_k ilike '%việt kiều%' then 'VIỆT KIỀU'
             else local_k
        end as tinh_noi
    from report
)

select
    r.*,
    case when r.tinh_noi = 'Bà Rịa - Vũng Tàu'       then 'Hồ Chí Minh và lân cận'
         when r.tinh_noi in ('Lào Cai', 'Yên Bái')    then 'Miền Bắc Mở Rộng'
         when r.tinh_noi = 'Thừa Thiên - Huế'         then 'Đà nẵng lân cận'
         when r.tinh_noi = 'KXĐ'                       then 'KXĐ'
         else grm.region
    end as region
from re_map r
left join {{ source('rmkd', 'ggs_region_map') }} grm on grm.location = r.tinh_noi
where r.date >= '20240101'

