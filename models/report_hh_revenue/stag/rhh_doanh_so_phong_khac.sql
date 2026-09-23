-- Doanh số các phòng khám CÒN LẠI — phần bệnh nhân không thuộc những phòng /
-- nhóm đã có model tính riêng. Dùng để cộng với các model kia ra tổng viện mà
-- không đếm trùng.
--
-- Loại 2 nhóm:
--   1. Nhóm người giới thiệu '[TPM]Thuê phòng mổ' -> đã có rhh_doanh_so_tpm.
--      Toàn bộ phần này nằm ở Phòng khám tổng hợp (roomid 48) và chiếm phần
--      lớn doanh số viện (T8/2026: 1.139 dòng / 12.850.342.615).
--   2. 4 phòng chuyên khoa đã có model riêng:
--        92  Phòng khám Ung bướu            -> rhh_doanh_so_ung_buou
--        276 Phòng khám LGBT                -> rhh_doanh_so_lgbt
--        94  Phòng khám Phẫu thuật thẩm mỹ  -> rhh_doanh_so_pttm
--        142 Phòng khám Sản [213]           -> rhh_doanh_so_san_khoa
--      Loại theo CẢ roomid lẫn roomid_kb, khớp cách 4 model kia nhận phòng.
--      (Đã kiểm T7/T8/T9-2026: lọc bằng riêng roomid_kb cho kết quả y hệt —
--      không có dòng nào 2 cột lệch nhau ở 4 phòng này — nhưng giữ cả 2 cho
--      chắc, vì khoản cọc luôn có roomid = 0.)
--
-- KHÔNG loại phiếu CBNV / nguồn rỗng ở đây: 4 model chuyên khoa có bộ lọc
-- riêng của chúng nên tổng 5 model < doanh số thật của các phòng đó. Phần
-- chênh (T8/2026: 1 dòng 267.537 của NGUYỄN THỊ PHƯỢNG, phòng Sản, nguồn
-- 'K - CBNV') KHÔNG rơi vào model này vì room 142 đã bị loại — nó không nằm
-- ở đâu cả. Đây là hành vi có chủ đích theo yêu cầu người dùng, không phải
-- lỗi; nếu muốn cân bằng tuyệt đối thì phải bỏ 142 khỏi danh sách loại.
--
-- Giữ nguyên khoản cọc (pl = 'Cọc trong tháng'). T8/2026 chỉ có 1 khoản cọc
-- 2.500.000 và nó thuộc phòng LGBT nên đã bị loại sẵn — model này không đổi
-- dù có trừ cọc hay không.
--
-- Đã verify T8/2026 = 713 dòng / 364.441.422, khớp số người dùng đối chiếu.
-- T7/2026 = 693 dòng / 370.423.550. T9/2026 (đến 17/09) = 283 dòng /
-- 139.179.643.

select
    *,
    date_trunc('month', invoicedate)::date as thang
from {{ ref('rhh_ehc_payment_service') }}
where coalesce(dm_hoahongnguoigioithieu_nguoigioithieuname, '') not ilike '%thuê phòng mổ%'
  and coalesce(roomid, -1)    not in (92, 276, 94, 142)
  and coalesce(roomid_kb, -1) not in (92, 276, 94, 142)
