with combine as (
    select * from {{ ref('rtc_combine') }}
),
page as (
    select * from {{ ref('rtc_page') }}
),
deal as (
    select * from {{ ref('rtc_deal') }}
),
new_cus as (
    select * from {{ ref('rtc_v_new_customer') }}
),
chat as (
    select * from {{ ref('rtc_chat') }}
)

select
    combine.*,
    row_number() over (
        partition by combine.type_report, combine.ticket_id
        order by combine.ngay_tao_khach
    ) as rnk,
    page.page_name,
    date(deal.convert_at) as ngay_chuyen_doi,
    deal.assignee_username as nguoi_chuyen_doi,
    date(new_cus.ngay_tao_khach) as ngay_tao_khach_moi,
    chat.agent_name as nguoi_nhan_inbox_dau_tien
from combine
left join page on page.ticket_id = combine.ticket_id
left join deal on deal.id = combine.ticket_id
left join new_cus on new_cus.requester_id::text = combine.requester_id
left join chat on chat.ticket_id = combine.ticket_id
