{{ config(alias='mart_chi_tieu') }}

with target_company_kn as (
    select
        a."time",
        a.brand_id,
        a.brand as "thương hiệu",
        a.company_id,
        a.company as "chi nhánh",
        a.target as "chỉ tiêu",
        a.release_date as "ngày ban hành"
    from {{ ref('stg_rtqdk_target_company') }} a
    where a.active is true
      and a.brand_id = 1
      and "time" >= '2026-01-01'

    union all

    select distinct
        "time",
        brand_id,
        "thương hiệu",
        company_id,
        "chi nhánh",
        "chỉ tiêu",
        "ngày ban hành"
    from {{ ref('stg_rtqdk_kangnam_chitieu') }}
    where "time"::date >= '20250801'
),

max_ban_hanh as (
    select
        "time",
        company_id,
        max("ngày ban hành") as max_ban_hanh
    from target_company_kn tpc
    group by "time", company_id
)

select m.*, m."chỉ tiêu" as "Chỉ tiêu"
from target_company_kn m
left join max_ban_hanh tpc
    on date(m."time") = date(tpc."time")
    and m.company_id = tpc.company_id
where date(tpc.max_ban_hanh) = date(m."ngày ban hành")
  and m."time" >= get_time_ago_report()

