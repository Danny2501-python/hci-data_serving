with source as (
    select * from {{ source('kangnam_source', 'view_stag_tongquan_khachhang_sm1') }}
),
arrival as (
    select * from {{ source('kangnam_source', 'stag_crm_booking_arrival_company') }}
    where brand_etl = 1
)

select
    s.*,
    a.arrival_company,
    coalesce(a.arrival_company, s.chinhanh) as chi_nhanh_new,
    s.vao_so as ma_phieu
from source s
left join arrival a on s.id = a.crm_id
where s.nhom_dv <> 'SAN PHAM'
and s.nhom_dv is not null
