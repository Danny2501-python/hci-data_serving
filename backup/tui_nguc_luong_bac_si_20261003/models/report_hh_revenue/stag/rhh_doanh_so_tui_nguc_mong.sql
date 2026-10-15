-- Khoản TRỪ chi phí vật tư túi ngực/túi mông của khách thuê phòng mổ — port
-- nguyên logic nhánh `tui_nguc_mong` của report_tableau_doanh_so_tap_doan_HCI/
-- int/int_rtds_hongha.sql (nhánh bao_cao_doanh_so_tap_doan_20260826, user đã
-- xác nhận số T1-T9/2026 ngày 2026-09-12). sotienphieu = -tongbenhnhan (ÂM).
--
-- Nguồn ehc_tb_servicedata, KHÔNG qua ehc_tb_invoice (invoiceid trên các dòng
-- vật tư này luôn = 0) -> ngày lấy servicedatadate.
--
-- Điều kiện:
--   - servicecode like 'VT%' (vật tư) — loại các dòng DỊCH VỤ PTTM/gây mê có
--     tên nhắc "túi ngực, túi mông" chỉ để ghi KHÔNG BAO GỒM.
--   - servicename có tiền tố size dạng `(X)` ở đầu (vd "(L) Túi ngực Perle");
--     túi không tiền tố / phụ kiện ("Cây đẩy túi ngực") KHÔNG trừ.
--   - Khách (patientrecordid) từng có dịch vụ thuê phòng mổ
--     (dm_report_groupid = 5) bất kỳ lúc nào.
--
-- Cột xếp đúng thứ tự các khối union trong mart/rhh_ehc_payment_service.

with tpm as (
    select distinct patientrecordid
    from {{ source('rhh_base', 'ehc_tb_servicedata') }}
    where dm_report_groupid = 5
)

select
    etn.nguoigioithieuname          as source_ehc,
    etp.id_booking,
    sd.servicedatadate::date        as invoicedate,
    -sd.tongbenhnhan                as sotienphieu,
    sd.servicename                  as invoiceremark,
    'Trừ túi ngực/mông'::text       as loaiphieu,
    'tuimong-' || sd.servicedataid::text as sophieu,
    etp.patientphone,
    etp.patientname,
    etp.patientcode,
    sd.patientrecordid,
    null::integer                   as invoiceid,
    dgt.dm_hoahongnguoigioithieu_nguoigioithieuname,
    sd.roomid,
    etp.roomid_kb,
    'DT trừ cọc trong tháng'::text  as pl
from {{ source('rhh_base', 'ehc_tb_servicedata') }} sd
join tpm on tpm.patientrecordid = sd.patientrecordid
left join {{ source('rhh_base', 'ehc_tb_patientrecord') }} etp
       on etp.patientrecordid = sd.patientrecordid
left join {{ source('rhh_base', 'ehc_tb_nguoigioithieu') }} etn
       on etn.nguoigioithieuid = etp.nguoigioithieuid
left join {{ source('rhh_base', 'ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu') }} dgt
       on dgt.dm_hoahongnguoigioithieu_nguoigioithieuid
        = etn.dm_hoahongnguoigioithieu_nguoigioithieuid
where sd.servicecode like 'VT%'
  and sd.servicename ~ '^\s*\('
  and (sd.servicename ilike '%túi ngực%' or sd.servicename ilike '%túi mông%')
