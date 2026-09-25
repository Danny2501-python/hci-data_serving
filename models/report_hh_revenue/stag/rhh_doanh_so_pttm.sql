-- Doanh số khách hàng PTTM (Phòng khám Phẫu thuật thẩm mỹ = roomid 94) —
-- khác với rhh_doanh_so_tpm.sql (theo NHÓM NGUỒN "[TPM]Thuê phòng mổ").
--
-- QUAN TRỌNG: không lọc trực tiếp WHERE roomid = 94, vì:
--   1. 1 khách hàng thực tế (patientcode) có thể có nhiều patientrecordid/
--      booking qua các lần khám khác nhau, mỗi lần phát sinh phiếu ở roomid
--      khác nhau.
--   2. Room của khách nằm ở CẢ 2 chỗ: roomid (của từng phiếu, ehc_tb_invoice)
--      VÀ roomid_kb (của hồ sơ bệnh nhân, ehc_tb_patientrecord) — có khách
--      chỉ dính room qua roomid_kb, không phiếu nào có roomid=94 (đã gặp case
--      này ở rhh_doanh_so_lgbt, room 276 — áp dụng chung rule cho chắc).
--
-- Cách tính (đã verify khớp thực tế tháng 7: 563,740,000/19 dòng, tháng 8:
-- 48,000,000/2 dòng — trước khi thêm điều kiện roomid_kb; PTTM không có case
-- roomid_kb-only nên số không đổi khi thêm điều kiện này):
--   1. Trong TỪNG THÁNG, tìm tập patientcode có ÍT NHẤT 1 phiếu roomid = 94
--      HOẶC roomid_kb = 94.
--   2. Lấy TOÀN BỘ doanh thu TRONG THÁNG ĐÓ của các patientcode đó (mọi
--      phiếu, mọi roomid).
-- Gán theo TỪNG THÁNG riêng (không phải theo lịch sử toàn thời gian).

with base as (
    select
        *,
        date_trunc('month', invoicedate)::date as thang
    from {{ ref('rhh_ehc_payment_service_base') }}
),

pttm_patientcode as (
    select distinct thang, patientcode
    from base
    where (roomid = 94 or roomid_kb = 94) and patientcode is not null
)

select base.*
from base
join pttm_patientcode
       on pttm_patientcode.patientcode = base.patientcode
      and pttm_patientcode.thang = base.thang
