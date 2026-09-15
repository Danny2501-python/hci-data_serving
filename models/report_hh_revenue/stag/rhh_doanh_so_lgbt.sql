-- Doanh số khách hàng LGBT (Phòng khám LGBT = roomid 276). Cùng logic với
-- rhh_doanh_so_pttm.sql (xem comment ở đó) — chỉ khác roomid mục tiêu (276
-- thay vì 94). Đã verify khớp thực tế tháng 7: 541,780,000/30 dòng/19 khách
-- (danh sách người dùng đưa thiếu đúng 1 dòng — ĐỖ THỊ THU HÀ/26008147/
-- 2,000,000 — đã xác nhận với người dùng khoản cọc tính theo ngayyeucau nên
-- dòng này đúng thuộc tháng 7, không phải lỗi).

with base as (
    select
        *,
        date_trunc('month', invoicedate)::date as thang
    from {{ ref('rhh_ehc_payment_service') }}
),

lgbt_patientcode as (
    select distinct thang, patientcode
    from base
    where (roomid = 276 or roomid_kb = 276) and patientcode is not null
)

select base.*
from base
join lgbt_patientcode
       on lgbt_patientcode.patientcode = base.patientcode
      and lgbt_patientcode.thang = base.thang
