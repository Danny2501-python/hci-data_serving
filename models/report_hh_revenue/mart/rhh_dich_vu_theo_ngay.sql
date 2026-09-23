-- Chi tiết DỊCH VỤ thực hiện, 1 dòng duy nhất cho mỗi (bệnh nhân, ngày, dịch vụ).
-- Dùng chung khoá (patientrecordid, ngay) với rhh_doanh_so_theo_ngay để join
-- không bị nhân dòng.
--
-- ehc_tb_servicedata ghi NHIỀU dòng cho cùng một dịch vụ trong ngày (mỗi lần
-- thực hiện / mỗi lô vật tư một dòng) — vd hồ sơ 130665 ngày 21/09 có 160 dòng
-- nhưng chỉ 100 serviceid. Model gom lại theo serviceid, cộng soluong và tiền.
--
-- CẢNH BÁO khi đọc số: phần lớn dòng có thanh_tien = 0 vì đã gộp trong giá gói.
-- Hồ sơ 130665: 100 dịch vụ / chỉ 1 dịch vụ có tiền (CKDQ0001 RFA 22.000.000).
-- Bóc theo nhóm (T8/2026 của hồ sơ đó): VATTU 51, XN 34, THUOC 11, còn lại 4.
-- Nhóm XN phình lên vì MỖI CHỈ SỐ xét nghiệm là 1 dòng (KQ_HH01 = WBC,
-- KQ_HH02 = RBC...), soluong = 0, không phải dịch vụ tính tiền.
-- Lọc `thanh_tien > 0` để chỉ lấy dịch vụ thật sự phát sinh doanh thu.
--
-- thanh_tien là GIÁ TRỊ DỊCH VỤ CHỈ ĐỊNH, không phải tiền đã thu — hai cột
-- tongdathu/sotiencanthu của HIS rỗng 100%. Muốn tiền thu thì lấy bên
-- rhh_doanh_so_theo_ngay.
--
-- id_booking / patientcode / patientname / source_ehc / nhom_nguon lấy từ
-- ehc_tb_patientrecord theo patientrecordid (khoá DUY NHẤT: 128.208 dòng /
-- 128.208 patientrecordid) nên 3 join này không nhân dòng. Chuỗi nguồn giống
-- hệt rhh_ehc_payment_service: patientrecord -> nguoigioithieu -> danh mục
-- nhóm, join bằng ...id chứ KHÔNG phải ...dbid.
--
-- Nhóm dịch vụ join qua ehc_tb_service.serviceid rồi sang danh mục; phải dùng
-- dm_servicegroupid chứ KHÔNG phải dm_servicegroupdbid (2 bảng danh mục đều có
-- cả hai cột, dùng nhầm dbid ra nhóm sai).
-- Độ phủ T8/2026: khớp ehc_tb_service 100%, có nhóm 100%, có nhóm con 88,6%.
--
-- CỜ CHỐNG CỘNG TRÙNG: `la_dong_tinh_doanh_so` bật true ở ĐÚNG MỘT dòng trong
-- mỗi (patientrecordid, ngay) — dòng dịch vụ có tiền cao nhất. Khi join sang
-- rhh_doanh_so_theo_ngay (1 dòng/khoá) thì tiền lặp lại ở mọi dòng dịch vụ;
-- dùng cờ này để cộng tiền đúng 1 lần theo phiếu thu:
--     sum(case when coalesce(dv.la_dong_tinh_doanh_so, true)
--              then ds.sotien else 0 end)
-- coalesce(..., true) để không mất các ngày có phiếu thu nhưng không có dòng
-- dịch vụ nào (T8/2026: 32,8% cặp (prid, invoicedate) rơi vào trường hợp này
-- vì ngày thu tiền khác ngày thực hiện dịch vụ).

with gom as (
select
    sd.patientrecordid,
    sd.servicedatadate::date as ngay,
    sd.serviceid,
    min(etp.id_booking)     as id_booking,
    min(etp.patientcode)    as patientcode,
    min(etp.patientname)    as patientname,
    min(etn.nguoigioithieuname) as source_ehc,
    min(dgt.dm_hoahongnguoigioithieu_nguoigioithieuname) as nhom_nguon,
    min(sd.servicecode)             as servicecode,
    min(sd.servicename)             as servicename,
    min(g.dm_servicegroupcode)      as nhom_code,
    min(g.dm_servicegroupname)      as nhom_ten,
    min(sg.dm_servicesubgroupcode)  as nhom_con_code,
    min(sg.dm_servicesubgroupname)  as nhom_con_ten,
    count(*)                        as so_dong_goc,
    sum(sd.soluong)                 as soluong,
    sum(sd.thanh_tien)              as thanh_tien,
    sum(sd.tongbenhnhan)            as tongbenhnhan,
    sum(sd.tongchiphi)              as tongchiphi
from {{ source('rhh_base', 'ehc_tb_servicedata') }} sd
left join {{ source('rhh_base', 'ehc_tb_service') }} s
       on s.serviceid = sd.serviceid
left join {{ source('rhh_base', 'ehc_tb_dm_servicegroup') }} g
       on g.dm_servicegroupid = s.dm_servicegroupid
left join {{ source('rhh_base', 'ehc_tb_dm_servicesubgroup') }} sg
       on sg.dm_servicesubgroupid = s.dm_servicesubgroupid
left join {{ source('rhh_base', 'ehc_tb_patientrecord') }} etp
       on etp.patientrecordid = sd.patientrecordid
left join {{ source('rhh_base', 'ehc_tb_nguoigioithieu') }} etn
       on etn.nguoigioithieuid = etp.nguoigioithieuid
left join {{ source('rhh_base', 'ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu') }} dgt
       on dgt.dm_hoahongnguoigioithieu_nguoigioithieuid = etn.dm_hoahongnguoigioithieu_nguoigioithieuid
where sd.patientrecordid is not null
  and sd.servicedatadate is not null
group by sd.patientrecordid, sd.servicedatadate::date, sd.serviceid
)

select
    gom.*,
    row_number() over (
        partition by gom.patientrecordid, gom.ngay
        order by gom.thanh_tien desc nulls last, gom.serviceid
    ) as stt_trong_ngay,
    row_number() over (
        partition by gom.patientrecordid, gom.ngay
        order by gom.thanh_tien desc nulls last, gom.serviceid
    ) = 1 as la_dong_tinh_doanh_so
from gom
