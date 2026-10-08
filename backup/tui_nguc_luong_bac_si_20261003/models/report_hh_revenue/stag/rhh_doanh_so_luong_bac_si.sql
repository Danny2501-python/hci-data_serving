-- Khoản TRỪ lương bác sĩ PTTM theo ca ra viện, CHỈ năm 2026 — port nguyên CTE
-- `luong_bs` của report_tableau_doanh_so_tap_doan_HCI/int/int_rtds_hongha.sql
-- (nhánh bao_cao_doanh_so_tap_doan_20260826, commit 60e2f04 ngày 2026-09-28).
-- sotienphieu ÂM.
--
-- 3 mã thuộc bảng giá "2026-L" (chỉ phát sinh từ 2026-01-02):
--   - Đại phẫu  = DVHH0700 "Dịch vụ PTTM (gây mê)" 13.000.000 -> trừ 2.000.000/ca.
--   - Tiểu phẫu = DVHH0701 "(tiền mê)" 3.900.000 / DVHH0702 "(Gây tê)" 3.000.000
--                 -> trừ 500.000/ca.
-- Lọc theo servicecode, KHÔNG theo đơn giá (nhiều dịch vụ khác trùng giá).
-- 1 ca = 1 patientrecordid x 1 loại: nhiều dòng cùng loại tính 1 ca; hồ sơ có
-- cả đại lẫn tiểu phẫu trừ cả 2 khoản. Chỉ dòng tongbenhnhan > 0.
-- Chỉ hồ sơ ĐÃ RA VIỆN (dm_patientrecordstatusid = 1), ngày ghi nhận =
-- medicalrecorddate_out; chưa ra viện (0001-01-01) chưa trừ.
--
-- [2026-09-29] KHÁC bản Tableau: chỉ tính dòng dịch vụ ĐÃ THỰC HIỆN
-- (dm_servicedatastatusid = 3). Trạng thái 1 = chỉ định nhưng chưa mổ (không có
-- phiếu PTTT; 2.527/2.527 dòng có phiếu PTTT đều = 3). Vd KH 26008089: hồ sơ
-- 122151 (14/08) chỉ định gây mê 13tr, trạng thái 1, khách chỉ đóng 2,52tr, mổ
-- thật ở hồ sơ 122442 (21/08) -> bản cũ trừ lương 2 lần. 2026 bớt 56 ca đại
-- (112tr) + 11 ca tiểu (5,5tr).
--
-- bac_si = phẫu thuật viên chính (ehc_tb_servicedata_pttt.userid_phauthuatvien_1
-- -> ehc_tb_nhanvien). 2026: mỗi ca đúng 1 PTV (2.531 ca), ~70 ca chưa ghi PTV
-- -> NULL. KHÔNG dùng servicedata.do_userid (phần lớn là điều dưỡng/nhập liệu).
-- loai_phau_thuat = 'Đại phẫu' / 'Tiểu phẫu' (1 dòng = 1 hồ sơ x 1 loại, không nhân dòng).
--
-- Cột xếp đúng thứ tự các khối union trong mart/rhh_ehc_payment_service.

with luong_bs as (
    select
        sd.patientrecordid,
        case when sd.servicecode = 'DVHH0700' then 'dai' else 'tieu' end as loai_phau,
        max(nullif(p.userid_phauthuatvien_1, 0)) as userid_ptv
    from {{ source('rhh_base', 'ehc_tb_servicedata') }} sd
    left join {{ source('rhh_base', 'ehc_tb_servicedata_pttt') }} p
           on p.servicedataid = sd.servicedataid
    where sd.servicecode in ('DVHH0700', 'DVHH0701', 'DVHH0702')
      and sd.tongbenhnhan > 0
      and sd.dm_servicedatastatusid = 3
      and sd.servicedatadate >= date '2026-01-01'
    group by 1, 2
)

select
    etn.nguoigioithieuname          as source_ehc,
    etp.id_booking,
    etp.medicalrecorddate_out::date as invoicedate,
    (case lbs.loai_phau when 'dai' then -2000000 else -500000 end)::double precision as sotienphieu,
    case lbs.loai_phau when 'dai' then 'Đại phẫu' else 'Tiểu phẫu' end as invoiceremark,
    'Trừ lương bác sĩ PTTM'::text   as loaiphieu,
    'luongbs-' || lbs.loai_phau || '-' || lbs.patientrecordid::text as sophieu,
    etp.patientphone,
    etp.patientname,
    etp.patientcode,
    lbs.patientrecordid,
    null::integer                   as invoiceid,
    dgt.dm_hoahongnguoigioithieu_nguoigioithieuname,
    null::integer                   as roomid,
    etp.roomid_kb,
    'DT trừ cọc trong tháng'::text  as pl,
    nv.nhanvienname::text           as bac_si,
    case lbs.loai_phau when 'dai' then 'Đại phẫu' else 'Tiểu phẫu' end::text as loai_phau_thuat
from luong_bs lbs
join {{ source('rhh_base', 'ehc_tb_patientrecord') }} etp
  on etp.patientrecordid = lbs.patientrecordid
 and etp.dm_patientrecordstatusid = 1
 and etp.medicalrecorddate_out >= date '2026-01-01'
left join {{ source('rhh_base', 'ehc_tb_nguoigioithieu') }} etn
       on etn.nguoigioithieuid = etp.nguoigioithieuid
left join {{ source('rhh_base', 'ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu') }} dgt
       on dgt.dm_hoahongnguoigioithieu_nguoigioithieuid
        = etn.dm_hoahongnguoigioithieu_nguoigioithieuid
left join {{ source('rhh_base', 'ehc_tb_nhanvien') }} nv
       on nv.nhanvienid = lbs.userid_ptv
