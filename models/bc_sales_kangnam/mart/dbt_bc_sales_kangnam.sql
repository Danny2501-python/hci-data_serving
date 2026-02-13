
select * from {{ ref('lead_total') }}
union all
select * from {{ ref('booking') }}
union all
select * from {{ ref('hen_lich') }}
union all
select * from {{ ref('den_cua') }}
union all
select * from {{ ref('thanh_cong') }}
union all 
select * from {{ ref('doanh_so') }}
