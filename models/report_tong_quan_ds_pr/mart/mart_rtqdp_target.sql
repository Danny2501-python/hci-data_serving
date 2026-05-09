with max_ban_hanh as (
    select 
        "time", 
        company_id, 
        coalesce(id_nguon, '0') as id_nguon, 
        max("ngày ban hành") as max_ban_hanh 
    from {{ ref('stg_rtqdp_target_paris_chitieu') }}
    group by "time", company_id, id_nguon
)
select 
    m.*, 
    "chỉ tiêu" * replace(ti_trong_nguon, ',', '.')::numeric as chi_tieu_nguon
from {{ ref('stg_rtqdp_target_paris_chitieu') }} m 
left join max_ban_hanh tpc 
    on date(m."time") = date(tpc."time") 
    and m.company_id = tpc.company_id 
    and coalesce(m.id_nguon, '0') = tpc.id_nguon
where date(tpc.max_ban_hanh) = date(m."ngày ban hành") 
    and m."time" >= get_time_ago_report()
