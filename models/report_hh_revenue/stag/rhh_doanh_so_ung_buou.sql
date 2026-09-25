-- Doanh số Ung bướu (Phòng khám Ung bướu = roomid 92).
--
-- Lọc THẲNG trên từng dòng, không gom theo patientcode — giống
-- rhh_doanh_so_san_khoa, KHÁC rhh_doanh_so_pttm/lgbt (2 model đó lấy toàn bộ
-- doanh thu trong tháng của khách có dính phòng). Nếu gom theo patientcode,
-- T7/2026 sẽ là 355.994.503/47 dòng thay vì 334.378.790/40 dòng.
--
-- Nhận phòng qua CẢ roomid lẫn roomid_kb:
--   - roomid    : phòng của TỪNG PHIẾU (ehc_tb_invoice); khoản cọc luôn = 0.
--   - roomid_kb : phòng của HỒ SƠ bệnh nhân (ehc_tb_patientrecord).
-- Ở phòng 92 tập `roomid = 92` (28 dòng T7) nằm trọn trong `roomid_kb = 92`
-- (40 dòng T7) nên `or` ra đúng bằng roomid_kb — ngược với phòng 142, ở đó
-- roomid mới là tập rộng hơn. Giữ cả 2 điều kiện cho chắc.
--
-- Điều kiện người giới thiệu (người dùng chốt):
--   1. source_ehc (TÊN người giới thiệu) không chứa 'CBNV' — bắt đủ 5 biến
--      thể: 'K - CBNV', 'K - Người nhà CBNV', 'DG - N - CBNV',
--      'DG - N - Người nhà CBNV', 'CBNV_Bạn bè/họ hàng/người thân'.
--   2. Cột NHÓM (dm_hoahongnguoigioithieu_nguoigioithieuname) không rỗng.
--   3. Cột NHÓM không chứa 'Thuê phòng mổ' — tức loại nhóm '[TPM]Thuê phòng
--      mổ'. LƯU Ý: chuỗi 'Thuê phòng mổ' có ở CẢ 2 cột ('Thuê phòng mổ_Bác sĩ
--      nội bộ' bên source_ehc), nhưng điều kiện này CHỈ áp cho cột nhóm, đúng
--      như người dùng chốt.
--
-- Dòng có source_ehc NULL tự rớt qua điều kiện 2 (đã verify: nhóm NULL trùng
-- khớp với source_ehc NULL, không có ca lệch), nên không cần thêm
-- `source_ehc is not null` riêng.
--
-- sotienphieu ở rhh_ehc_payment_service ĐÃ đảo dấu sẵn cho Hoàn tiền/Hoàn ứng
-- (dm_invoice_typeid 2/4) nên cộng thẳng ra doanh thu ròng.
--
-- Đã verify khớp số người dùng: T7/2026 = 334.378.790 (40 dòng — bộ lọc không
-- loại dòng nào ở tháng này). Tháng bị ảnh hưởng nhiều nhất là T4/2026
-- (109.178.118 -> 84.827.200, loại 4 dòng CBNV) và T5/2026 (11.131.520 ->
-- 650.000, loại 1 dòng nhóm [TPM] trị giá 10.481.520).

select
    *,
    date_trunc('month', invoicedate)::date as thang
from {{ ref('rhh_ehc_payment_service_base') }}
where (roomid = 92 or roomid_kb = 92)
  and source_ehc not ilike '%cbnv%'
  and dm_hoahongnguoigioithieu_nguoigioithieuname is not null
  and btrim(dm_hoahongnguoigioithieu_nguoigioithieuname) <> ''
  and dm_hoahongnguoigioithieu_nguoigioithieuname not ilike '%thuê phòng mổ%'
