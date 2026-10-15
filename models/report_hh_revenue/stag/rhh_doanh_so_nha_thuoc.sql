-- Doanh số nhà thuốc (HH) — chuyển từ code báo cáo "Thu tiền nhà thuốc theo
-- thời gian thu tiền" bên HIS, giữ nguyên logic, đổi tên bảng sang DWH
-- (tb_X -> ehc_tb_X) và bổ sung cột nguồn khách hàng theo yêu cầu người dùng.
--
-- Nguồn: ehc_tb_invoicemedicine — hoá đơn nhà thuốc, TÁCH RIÊNG khỏi
-- ehc_tb_invoice (viện phí). Vì vậy doanh số nhà thuốc KHÔNG nằm trong
-- rhh_ehc_payment_service, cũng không nằm trong 7 dòng "doanh số theo nhóm
-- dịch vụ" của báo cáo — nó là khoản riêng (T8/2026: báo cáo ghi
-- I. Doanh số Bệnh viện 8.127.370 = 1.1 nhóm dịch vụ 7.924.472 + nhà thuốc
-- 202.898).
--
-- Điều kiện gốc: chỉ `huyphieu_status = 0`. KHÔNG thêm
-- `dm_invoice_hinhthucid <> 999` như rhh_thuchi — bảng này chưa từng có
-- hinhthucid 999 (chỉ có 0/1/2/3) nên 2 cách ra cùng số, giữ đúng code gốc.
--
-- BỔ SUNG so với code gốc: cột nhóm nguồn
-- dm_hoahongnguoigioithieu_nguoigioithieuname, join qua
-- dm_hoahongnguoigioithieu_nguoigioithieuid = ...id của ehc_tb_nguoigioithieu
-- (ĐÃ VERIFY ở rhh_ehc_payment_service: KHÔNG dùng ...dbid — join theo dbid
-- cho kết quả sai, vd nhóm id=2 ra "Bảo hiểm y tế" thay vì "BP Kinh Doanh").
--
-- Đổi 5 subquery tương quan của code gốc thành left join — kết quả y hệt,
-- nhanh hơn nhiều. ĐÃ VERIFY 4 join đều 1-1, không fan-out:
--   ehc_tb_medicinebill  1.124.203 dòng / 1.124.203 medicinebillid distinct
--   ehc_tb_patientrecord   128.040 dòng /   128.040 patientrecordid distinct
--   ehc_tb_nguoigioithieu      389 dòng /       389 nguoigioithieuid distinct
--   ehc_tb_dm_hoahong...        42 dòng /        42 id distinct
--
-- KHÁC code gốc: bỏ `invoicemedicinedate >= {DATE_FROM} and <= {DATE_TO}` —
-- 2 placeholder runtime của công cụ báo cáo HIS, dbt không có tham số tương
-- đương. Model giữ toàn bộ lịch sử, phía dùng tự lọc `thang`/`ngay`.
--
-- Toàn bộ 41.144 hoá đơn đều có dm_invoice_typeid = 1 (phiếu thu) — không có
-- hoàn tiền/miễn giảm, nên KHÔNG cần đảo dấu như bên viện phí.
--
-- Đã verify T8/2026 = 202.897.610 / 352 hoá đơn, khớp số người dùng (202.898
-- nghìn). Toàn lịch sử: 41.144 hoá đơn / 23.108.745.175, từ 21/09/2018.
-- Phần lớn hoá đơn không truy được nguồn (T8/2026: 314/352 dòng, 186.351.302
-- có nhóm nguồn NULL) vì hồ sơ bệnh nhân không gán người giới thiệu.
--
-- FALLBACK người giới thiệu khi hồ sơ của phiếu không ra nguoigioithieuid
-- (chủ yếu patientrecordid = 0 — khách lẻ), giống rtr_ehc_payment_medicine bên
-- THV: lấy tên (khachlename) + SĐT (khachle_phone) của khách mua thuốc, tìm
-- các hồ sơ trùng CẢ tên LẪN SĐT (ehc_tb_patientrecord), lấy người giới thiệu
-- của lần dùng DỊCH VỤ ĐẦU TIÊN (phiếu ehc_tb_invoice sớm nhất, không huỷ, hồ
-- sơ có người giới thiệu). KHÔNG khớp theo tên thuần (trùng tên chưa chắc cùng
-- 1 người — theo yêu cầu người dùng). Không khớp -> NULL (Thuốc bán lẻ).
-- Chỉ bổ sung người giới thiệu (source_ehc + nhóm hoa hồng); patientcode/
-- patientname/patientphone vẫn theo hồ sơ gốc của phiếu.

-- Nguồn của lần dùng dịch vụ đầu tiên theo (tên, SĐT): 1 dòng / cặp tên-SĐT.
with first_service_ngt as (
    select distinct on (pr.patientname, pr.patientphone)
        pr.patientname,
        pr.patientphone,
        pr.nguoigioithieuid
    from {{ source('rhh_base', 'ehc_tb_invoice') }} iv
    join {{ source('rhh_base', 'ehc_tb_patientrecord') }} pr
      on pr.patientrecordid = iv.patientrecordid
    where iv.huyphieu_status = 0
      and pr.nguoigioithieuid is not null
      and nullif(pr.patientphone, '') is not null
    order by pr.patientname, pr.patientphone, iv.invoicedate, iv.invoiceid
)

select
    date_trunc('month', i.invoicemedicinedate)::date as thang,
    i.invoicemedicinedate as ngay,
    concat(i.invoicemedicinegroupcode, '/', i.invoicemedicinestt) as sophieu,
    i.sotienphieu,
    i.invoicemedicineremark as ghichu,
    mb.khachlename as khachhang,
    etp.patientcode,
    etp.patientname,
    etp.patientphone,
    etn.nguoigioithieuname as source_ehc,
    etn.nguoigioithieuremark,
    etn.nguoigioithieuaddress,
    dgt.dm_hoahongnguoigioithieu_nguoigioithieuname,
    i.patientrecordid,
    i.medicinebillid
from {{ source('rhh_base', 'ehc_tb_invoicemedicine') }} i
left join {{ source('rhh_base', 'ehc_tb_medicinebill') }} mb
       on mb.medicinebillid = i.medicinebillid
left join {{ source('rhh_base', 'ehc_tb_patientrecord') }} etp
       on etp.patientrecordid = i.patientrecordid
left join first_service_ngt fb_sdt
       on etp.nguoigioithieuid is null
      and fb_sdt.patientname = mb.khachlename
      and fb_sdt.patientphone = nullif(mb.khachle_phone, '')
left join {{ source('rhh_base', 'ehc_tb_nguoigioithieu') }} etn
       on etn.nguoigioithieuid = coalesce(etp.nguoigioithieuid, fb_sdt.nguoigioithieuid)
left join {{ source('rhh_base', 'ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu') }} dgt
       on dgt.dm_hoahongnguoigioithieu_nguoigioithieuid
        = etn.dm_hoahongnguoigioithieu_nguoigioithieuid
where i.huyphieu_status = 0
