-- Đây là một câu query phân tích mẫu
-- Nó sẽ KHÔNG tạo bảng/view trong database
-- Nhưng vẫn dùng được sức mạnh của dbt (như hàm ref)

with vn_data as (
    select * 
    from {{ ref('country_codes') }}
    where country_code = 'VN'
)

select 
    count(*) as total_records,
    max(country_name) as sample_name
from vn_data
