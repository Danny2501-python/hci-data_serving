with base as (
    select * from {{ ref('temp_stag_tongquan_khachhang_sm') }}
),
pages as (
    select * from {{ ref('cte_page') }}
)

select
    b.*,
    p.page_name as page,
    case 
        when date(b.ngay_tao) <= '20240601' and b.work_email = 'anhktn@kangnam.vn' 
        then 'anhktn@scigroupvn.com'
        else b.work_email 
    end as work_email_normalized
from base b
left join pages p on cast(b.ticket_id as text) = cast(p.ticket_id as text)
