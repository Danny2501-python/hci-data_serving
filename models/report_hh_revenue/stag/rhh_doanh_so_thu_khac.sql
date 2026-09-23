-- Doanh số thu khác (HH) — khoản thu ngoài viện phí, ghi qua SỔ THU CHI
-- (rhh_thuchi), chủ yếu là tiền cho bác sĩ/đơn vị ngoài thuê phòng.
--
-- Điều kiện (người dùng chốt):
--   1. noidung = 'Thu tiền khác (Ghi nhận DS)' — so khớp CHÍNH XÁC, không
--      dùng ilike. CẨN THẬN: có một noidung anh em rất dễ nhầm là
--      'Thu tiền khác (0 ghi nhận DS)' (653 dòng / 9,0 tỷ — còn nhiều hơn
--      nhóm này), KHÔNG tính vào đây.
--   2. ghichu không chứa 'bao hiem' — loại các khoản BHXH tạm ứng/thanh toán
--      KCB BHYT. LƯU Ý: ghichu trong dữ liệu viết KHÔNG DẤU ('BAO HIEM XA
--      HOI ...'), không có dòng nào viết 'BẢO HIỂM' — nên ilike '%bao hiem%'
--      là đủ. Nếu sau này có người nhập có dấu thì phải thêm biến thể.
--   3. ghichu không chứa 'KSK' — phần khám sức khỏe đã tách riêng sang
--      rhh_doanh_so_ksk, để đây sẽ đếm trùng.
--
-- Dùng coalesce(ghichu,'') thay vì ghichu trần: `NULL not ilike '...'` trả
-- NULL nên dòng ghichu NULL sẽ bị loại nhầm. Hiện nhóm này không có dòng NULL
-- nào (2 cách ra cùng 284 dòng / 8.192.693.738) nhưng để vậy cho an toàn.
--
-- Lấy sotien_thu (heso = 1). Cả 293 dòng của noidung này đều là thu,
-- sotien_chi = 0.
--
-- Không lọc thời gian — phía dùng tự lọc `thang`/`ngay`.
--
-- Đã verify khớp số người dùng: T7/2026 = 133.500.000 (3 dòng, đều là tiền
-- thuê phòng của BS Hoàng Cương / Cty Rasa-BS Lê Trung Kiên / BS Tạ Xuân Sơn).
-- Toàn bộ: 284 dòng / 8.192.693.738, từ 11/08/2023.

select
    date_trunc('month', ngay)::date as thang,
    ngay,
    loaiphieu,
    noidung,
    sophieusothu as sophieu,
    nguoinopnhan as nguoinop,
    hinhthucthu,
    ghichu,
    sotien_thu as sotien
from {{ ref('rhh_thuchi') }}
where noidung = 'Thu tiền khác (Ghi nhận DS)'
  and coalesce(ghichu, '') not ilike '%bao hiem%'
  and coalesce(ghichu, '') not ilike '%KSK%'
