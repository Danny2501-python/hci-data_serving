with d as (select * from {{ ref('int_ibgs_d') }}),
k as (select * from {{ ref('int_ibgs_k') }}),
pp as (select * from {{ ref('int_ibgs_pp') }})

select
    d.*,
    case
        when sss.false_duplicate_product_id is not null then sss.false_duplicate_product_id
        when r.false_extenal_id is not null or r.false_extenal_id <> '' then r.false_extenal_id
        else null
    end status_data
from d
left join k sss on d.stt = sss.stt
left join pp r on r.stt = d.stt
