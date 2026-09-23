-- DOANH SỐ gom về 1 dòng duy nhất cho mỗi (bệnh nhân, ngày thu tiền).
-- Cùng khoá (patientrecordid, ngay) với rhh_dich_vu_theo_ngay.
--
-- Từ 166.153 phiếu còn 125.697 dòng — một hồ sơ thường có nhiều phiếu trong
-- cùng ngày (vd hồ sơ 130665 ngày 21/09 thu 5 phiếu = 22.000.000). Cộng
-- sotienphieu ở đây ra ĐÚNG tổng thu, không lặp.
--
-- LƯU Ý khi join 2 bảng theo (patientrecordid, ngay): chỉ 67,2% cặp khớp đúng
-- ngày (T8/2026: 1.104/1.642), vì NGÀY THU TIỀN ≠ NGÀY THỰC HIỆN DỊCH VỤ —
-- thêm 536 cặp có dịch vụ nhưng rơi vào ngày khác. Muốn phủ hết thì join theo
-- patientrecordid không kèm ngày: đã đo T8/2026 phủ 99,5% hồ sơ và 100,0%
-- doanh số (nhưng khi đó cờ la_dong_tinh_doanh_so phân vùng theo
-- (patientrecordid, ngay) sẽ đếm dư — phải tự lọc lại).
--
-- roomid đổi theo từng phiếu nên gom lại thành danh sách `cac_roomid`;
-- roomid_kb gắn với hồ sơ nên ổn định, lấy max. Các cột còn lại (id_booking,
-- patientcode, source_ehc, nhóm người giới thiệu) đều là thuộc tính của hồ sơ
-- nên max() an toàn.
--
-- sotien_coc tách riêng phần pl = 'Cọc trong tháng' để ai cần trừ cọc thì trừ;
-- sotien đã bao gồm cọc.

select
    patientrecordid,
    invoicedate                        as ngay,
    date_trunc('month', invoicedate)::date as thang,
    max(id_booking)                    as id_booking,
    max(patientcode)                   as patientcode,
    max(patientname)                   as patientname,
    max(patientphone)                  as patientphone,
    max(roomid_kb)                     as roomid_kb,
    string_agg(distinct roomid::text, ', ' order by roomid::text) as cac_roomid,
    max(source_ehc)                    as source_ehc,
    max(dm_hoahongnguoigioithieu_nguoigioithieuname) as nhom_nguon,
    max(erp_source_id_old)             as erp_source_id_old,
    max(old_source_name)               as old_source_name,
    max(erp_source_id_new)             as erp_source_id_new,
    max(new_source_name)               as new_source_name,
    count(*)                           as so_phieu,
    string_agg(distinct sophieu, ', ') as ds_phieu,
    sum(sotienphieu)                   as sotien,
    sum(sotienphieu) filter (where pl = 'Cọc trong tháng') as sotien_coc
from {{ ref('rhh_ehc_payment_service_test') }}
where patientrecordid is not null
  and invoicedate is not null
group by patientrecordid, invoicedate
