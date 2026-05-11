with max_ban_hanh as (
select "time" , company_id , coalesce(id_nguon,'0') id_nguon ,coalesce(id_kenh,'0') id_kenh , max("ngày ban hành") max_ban_hanh 
from {{ source('rmkdt', 'target_kangnam_chitieu') }} tpc
group by "time" , company_id , id_nguon,id_kenh
)
select m.*, "chỉ tiêu" * replace(m.ti_trong_nguon,',','.')::numeric  as chi_tieu_nguon,"chỉ tiêu" * replace(m.ti_trong_kenh,',','.')::numeric as chi_tieu_kenh ,
m."chỉ tiêu" as "Chỉ tiêu"
from {{ source('rmkdt', 'target_kangnam_chitieu') }} m 
left join max_ban_hanh tpc on date(m."time" ) = date(tpc."time") and m.company_id = tpc.company_id and coalesce(m.id_nguon,'0') = tpc.id_nguon and coalesce(m.id_kenh,'0') = tpc.id_kenh 
where date(tpc.max_ban_hanh) = date(m."ngày ban hành") and m."time" >= get_time_ago_report()
