-- Lấy bản target ĐANG HIỆU LỰC theo từng (ngay_dau_thang, chi_tieu) từ seed
-- rtr_target (giữ đầy đủ lịch sử các lần đổi target). Khi target thay đổi:
-- thêm 1 dòng mới active=true, đồng thời sửa dòng active=true cũ (cùng
-- ngay_dau_thang+chi_tieu) thành active=false — không xoá dòng cũ.
-- Nếu lỡ có >1 dòng active=true cùng (ngay_dau_thang, chi_tieu) (nhập sai,
-- quên tắt active dòng cũ) thì ưu tiên ngay_cap_nhat mới nhất, không lỗi.

with active_rows as (
    select * from {{ ref('rtr_target') }}
    where active = true
),

ranked as (
    select
        *,
        row_number() over (
            partition by ngay_dau_thang, chi_tieu
            order by ngay_cap_nhat desc
        ) as rn
    from active_rows
)

select ngay_dau_thang, chi_tieu, target, ngay_cap_nhat
from ranked
where rn = 1
