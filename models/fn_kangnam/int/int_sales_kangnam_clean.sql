with base as (
    select * from {{ ref('stg_sales_kangnam_base') }}
),
pages as (
    select * from {{ ref('stg_facebook_pages') }}
)

select
    b.*,
    -- Giữ nguyên tên cột như logic cũ, nhưng lấy từ mapping
    p.page_name as page,
    
    -- Xử lý logic email đặc biệt "anhktn"
    -- Lưu ý: Logic gốc dùng ngày tạo để check email, mình giữ nguyên logic đó
    case 
        when date(b.ngay_tao) <= '2024-06-01' and b.work_email = 'anhktn@kangnam.vn' 
        then 'anhktn@scigroupvn.com'
        else b.work_email 
    end as work_email_normalized -- Đặt tên mới để tránh nhầm lẫn
    
from base b
left join pages p on cast(b.ticket_id as text) = cast(p.ticket_id as text)
