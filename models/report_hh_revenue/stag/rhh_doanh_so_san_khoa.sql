-- Doanh số Sản khoa (Phòng khám Sản = roomid 142).
--
-- KHÁC rhh_doanh_so_pttm/rhh_doanh_so_lgbt: 2 model đó gom theo patientcode
-- trong tháng (lấy TOÀN BỘ doanh thu của khách có dính phòng). Sản khoa lọc
-- THẲNG trên từng dòng, không gom theo patientcode — đã đối chiếu với danh
-- sách thực tế của người dùng và khớp.
--
-- Nhận phòng qua CẢ roomid lẫn roomid_kb, giống 2 model kia:
--   - roomid    : phòng của TỪNG PHIẾU (ehc_tb_invoice); khoản cọc luôn = 0.
--   - roomid_kb : phòng của HỒ SƠ bệnh nhân (ehc_tb_patientrecord).
-- Có phiếu chỉ dính 142 qua roomid_kb — vd phiếu hoàn tiền -927.068 ngày
-- 02/07/2026 của ĐỖ THỊ NGUYỆT phát sinh ở roomid = 9, roomid_kb = 142. Lọc
-- mỗi `roomid = 142` sẽ bỏ sót dòng này.
--
-- Loại người giới thiệu CBNV (nhân viên + người nhà nhân viên) và các dòng
-- không có người giới thiệu:
--   - Lọc trên source_ehc (TÊN người giới thiệu), KHÔNG phải cột nhóm
--     dm_hoahongnguoigioithieu_nguoigioithieuname — nhóm '[CNV]SCI/CBNV' không
--     xuất hiện ở phòng 142 nên lọc theo nhóm sẽ không loại được gì.
--     ilike '%cbnv%' bắt đủ 5 biến thể đang có trong dữ liệu: 'K - CBNV',
--     'K - Người nhà CBNV', 'DG - N - CBNV', 'DG - N - Người nhà CBNV',
--     'CBNV_Bạn bè/họ hàng/người thân'.
--   - btrim(source_ehc) <> '' để phòng trường hợp rỗng/khoảng trắng (hiện dữ
--     liệu chưa có ca nào, chỉ có NULL).
--
-- LOẠI KHÁCH IVF: bỏ toàn bộ doanh thu của khách từng phát sinh dịch vụ
-- servicecode = 'SA_TIENIVF01' ("Siêu âm đầu dò lần 1 [Gói tiền IVF]",
-- serviceid 16348). Lọc ở mức KHÁCH HÀNG (patientcode) chứ không phải từng
-- lần khám (patientrecordid) — patientcode mới là mã ổn định của 1 người qua
-- nhiều patientrecordid/booking (xem comment rhh_ehc_payment_service.sql).
--   - Dùng ehc_tb_servicedata (bảng CHI TIẾT dịch vụ phát sinh, 32 dòng /
--     31 patientrecordid), KHÔNG phải ehc_tb_service (bảng danh mục, 1 dòng).
--     Cả 2 bảng đều có cột servicecode chứa giá trị này.
--   - Giữ `patientcode is null or ...` vì `NOT IN` gặp patientcode NULL sẽ
--     trả NULL và loại nhầm dòng đó.
--   - Cả 31 hồ sơ IVF đều có roomid_kb = 142 nên đều thuộc phạm vi sản khoa.
--     Phiếu của họ chỉ nằm trong 2020-11-05 -> 2023-03-26, nên điều kiện này
--     KHÔNG đổi số từ 2024 trở đi (2026 vẫn nguyên: T7 = 500.000,
--     T8 = 7.616.400). Ảnh hưởng dồn vào 2020-2022, tổng loại 1.414.578.571
--     trên toàn lịch sử.
--
-- sotienphieu ở rhh_ehc_payment_service ĐÃ đảo dấu sẵn cho Hoàn tiền/Hoàn ứng
-- (dm_invoice_typeid 2/4) nên cộng thẳng ra doanh thu ròng.

select
    *,
    date_trunc('month', invoicedate)::date as thang
from {{ ref('rhh_ehc_payment_service') }}
where (roomid = 142 or roomid_kb = 142)
  and source_ehc is not null
  and btrim(source_ehc) <> ''
  and source_ehc not ilike '%cbnv%'
  and (
        patientcode is null
     or patientcode not in (
            select distinct pr.patientcode
            from {{ source('rhh_base', 'ehc_tb_patientrecord') }} pr
            where pr.patientcode is not null
              and pr.patientrecordid in (
                    select sd.patientrecordid
                    from {{ source('rhh_base', 'ehc_tb_servicedata') }} sd
                    where sd.servicecode = 'SA_TIENIVF01'
              )
        )
  )
