-- Sổ thu chi (HH) — chuyển từ view gốc bên HIS `public.view_thuchi1`, giữ
-- nguyên logic, chỉ đổi tên bảng nguồn sang tên DWH (quy tắc tb_X -> ehc_tb_X).
-- Đã verify: chạy song song với bản gốc (chỉ đổi tên bảng) ra trùng md5 từng
-- dòng, 221.428 dòng, 2018-09-21 -> 2026-09-16.
--
-- 7 nhánh union all: tondauky / phieuthuchi / invoice / invoicemedicine /
-- hoahongbacsiinvoice / nguoigioithieuinvoice / ptttchi_invoice.
-- heso = 1 (thu) / -1 (chi), tách thành sotien_thu và sotien_chi.
--
-- KHÁC view gốc: bỏ `ngaythuchi >= {DATE_FROM} and ngaythuchi <= {DATE_TO}`
-- (placeholder runtime của công cụ báo cáo HIS, dbt không có tham số tương
-- đương) — model giữ toàn bộ lịch sử, phía dùng tự lọc theo `ngay`.
with temp_thuchi as (
    select
        tdk.tondaukydate as ngaythuchi,
        'TDK'::text as loaiphieu,
        1 as heso,
        null::text as noidung,
        tdk.sotientondauky as sotien,
        null::text as ghichu,
        null::text as sophieusothu,
        null::text as nguoinopnhan,
        null::text as hinhthucthu
    from {{ source('rhh_base', 'ehc_tb_phieuthuchi_tondauky') }} tdk
    where tdk.dm_invoice_hinhthucid <> 999
    union all
    select
        thuchi.phieuthuchidate as ngaythuchi,
        case
            when thuchi.dm_phieuthuchi_typeid = 1 then 'Phiếu thu'::text
            when thuchi.dm_phieuthuchi_typeid = 2 then 'Phiếu chi'::text
            else 'Chưa xác định'::text
        end as loaiphieu,
        case
            when thuchi.dm_phieuthuchi_typeid = 1 then 1
            when thuchi.dm_phieuthuchi_typeid = 2 then '-1'::integer
            else '-1'::integer
        end as heso,
        (select nd.dm_phieuthuchi_noidungname
           from {{ source('rhh_base', 'ehc_tb_dm_phieuthuchi_noidung') }} nd
          where nd.dm_phieuthuchi_noidungid = thuchi.dm_phieuthuchi_noidungid) as noidung,
        thuchi.sotienphieu as sotien,
        thuchi.phieuthuchiremark as ghichu,
        thuchi.nguoigioithieuinvoicecode_sothu as sophieusothu,
        thuchi.nguoinhan_ten as nguoinopnhan,
        (select ht.dm_invoice_hinhthucname
           from {{ source('rhh_base', 'ehc_tb_dm_invoice_hinhthuc') }} ht
          where ht.dm_invoice_hinhthucid = thuchi.dm_invoice_hinhthucid) as hinhthucthu
    from {{ source('rhh_base', 'ehc_tb_phieuthuchi') }} thuchi
    where thuchi.dm_invoice_hinhthucid <> 999
      and thuchi.huyphieu_status = 0
    union all
    select
        iv.invoicedate as ngaythuchi,
        case
            when iv.dm_invoice_typeid = 1 then 'Thu tiền'::text
            when iv.dm_invoice_typeid = 2 then 'Hoàn tiền'::text
            when iv.dm_invoice_typeid = 4 then 'Hoàn ứng'::text
            when iv.dm_invoice_typeid = 3 then 'Tạm ứng'::text
            when iv.dm_invoice_typeid = 6 then 'Thu 0đ'::text
            when iv.dm_invoice_typeid = 7 then 'Chi BHYT'::text
            else 'Chưa xác định'::text
        end as loaiphieu,
        case
            when iv.dm_invoice_typeid = 1 then 1
            when iv.dm_invoice_typeid = 2 then '-1'::integer
            when iv.dm_invoice_typeid = 4 then '-1'::integer
            when iv.dm_invoice_typeid = 3 then 1
            when iv.dm_invoice_typeid = 6 then 1
            when iv.dm_invoice_typeid = 7 then '-1'::integer
            else 1
        end as heso,
        case
            when iv.dm_invoice_typeid = 1 then 'Thu tiền'::text
            when iv.dm_invoice_typeid = 2 then 'Hoàn tiền'::text
            when iv.dm_invoice_typeid = 4 then 'Hoàn ứng'::text
            when iv.dm_invoice_typeid = 3 then 'Tạm ứng'::text
            when iv.dm_invoice_typeid = 6 then 'Thu 0đ'::text
            when iv.dm_invoice_typeid = 7 then 'Chi BHYT'::text
            else 'Chưa xác định'::text
        end as noidung,
        iv.sotienphieu as sotien,
        iv.invoiceremark as ghichu,
        concat(iv.invoicegroupcode, '/', iv.invoicestt) as sophieusothu,
        (select pr.patientname
           from {{ source('rhh_base', 'ehc_tb_patientrecord') }} pr
          where pr.patientrecordid = iv.patientrecordid) as nguoinopnhan,
        (select ht.dm_invoice_hinhthucname
           from {{ source('rhh_base', 'ehc_tb_dm_invoice_hinhthuc') }} ht
          where ht.dm_invoice_hinhthucid = iv.dm_invoice_hinhthucid) as hinhthucthu
    from {{ source('rhh_base', 'ehc_tb_invoice') }} iv
    where iv.dm_invoice_hinhthucid <> 999
      and iv.huyphieu_status = 0
    union all
    select
        ivm.invoicemedicinedate as ngaythuchi,
        case
            when ivm.dm_invoice_typeid = 1 then 'Thu tiền nhà thuốc'::text
            else 'Chưa xác định'::text
        end as loaiphieu,
        case
            when ivm.dm_invoice_typeid = 1 then 1
            else 1
        end as heso,
        case
            when ivm.dm_invoice_typeid = 1 then 'Thu tiền nhà thuốc'::text
            else 'Chưa xác định'::text
        end as noidung,
        ivm.sotienphieu as sotien,
        ivm.invoicemedicineremark as ghichu,
        concat(ivm.invoicemedicinegroupcode, '/', ivm.invoicemedicinestt) as sophieusothu,
        (select mb.khachlename
           from {{ source('rhh_base', 'ehc_tb_medicinebill') }} mb
          where mb.medicinebillid = ivm.medicinebillid) as nguoinopnhan,
        (select ht.dm_invoice_hinhthucname
           from {{ source('rhh_base', 'ehc_tb_dm_invoice_hinhthuc') }} ht
          where ht.dm_invoice_hinhthucid = ivm.dm_invoice_hinhthucid) as hinhthucthu
    from {{ source('rhh_base', 'ehc_tb_invoicemedicine') }} ivm
    where ivm.dm_invoice_hinhthucid <> 999
      and ivm.huyphieu_status = 0
    union all
    select
        hhbs.hoahongbacsiinvoicedate_finished as ngaythuchi,
        case
            when hhbs.dm_hoahongbacsiinvoice_typeid = 1 then 'Chi bác sĩ chỉ định '::text
            when hhbs.dm_hoahongbacsiinvoice_typeid = 2 then 'Chi bác sĩ thực hiện'::text
            else 'Chưa xác định'::text
        end as loaiphieu,
        '-1'::integer as heso,
        case
            when hhbs.dm_hoahongbacsiinvoice_typeid = 1 then 'Chi bác sĩ chỉ định '::text
            when hhbs.dm_hoahongbacsiinvoice_typeid = 2 then 'Chi bác sĩ thực hiện'::text
            else 'Chưa xác định'::text
        end as noidung,
        hhbs.sotienphieu as sotien,
        hhbs.hoahongbacsiinvoiceremark as ghichu,
        hhbs.hoahongbacsiinvoicecode_sothu as sophieusothu,
        (select nv.nhanvienname
           from {{ source('rhh_base', 'ehc_tb_nhanvien') }} nv
          where nv.nhanvienid = hhbs.nhanvienid) as nguoinopnhan,
        'Không xác định' as hinhthucthu
    from {{ source('rhh_base', 'ehc_tb_hoahongbacsiinvoice') }} hhbs
    where hhbs.dm_hoahongbacsiinvoice_statusid = 3
    union all
    select
        nggt.nguoigioithieuinvoicedate_finished as ngaythuchi,
        'Chi người giới thiệu'::text as loaiphieu,
        '-1'::integer as heso,
        'Chi người giới thiệu'::text as noidung,
        nggt.sotienphieu as sotien,
        nggt.nguoigioithieuinvoiceremark as ghichu,
        nggt.nguoigioithieuinvoicecode_sothu as sophieusothu,
        (select ngt.nguoigioithieuname
           from {{ source('rhh_base', 'ehc_tb_nguoigioithieu') }} ngt
          where nggt.nguoigioithieuid = ngt.nguoigioithieuid) as nguoinopnhan,
        'Không xác định' as hinhthucthu
    from {{ source('rhh_base', 'ehc_tb_nguoigioithieuinvoice') }} nggt
    where nggt.dm_nguoigioithieuinvoice_statusid = 3
      and nggt.huyphieu_status = 0
    union all
    select
        pttt.ptttchi_invoicedate_finished as ngaythuchi,
        'Chi phẫu thuật thủ thuật'::text as loaiphieu,
        '-1'::integer as heso,
        'Chi phẫu thuật thủ thuật'::text as noidung,
        pttt.sotienphieu as sotien,
        pttt.ptttchi_invoiceremark as ghichu,
        pttt.ptttchi_invoicecode_sothu as sophieusothu,
        (select nv.nhanvienname
           from {{ source('rhh_base', 'ehc_tb_nhanvien') }} nv
          where nv.nhanvienid = pttt.nhanvienid) as nguoinopnhan,
        'Không xác định' as hinhthucthu
    from {{ source('rhh_base', 'ehc_tb_ptttchi_invoice') }} pttt
    where pttt.dm_ptttchi_invoice_statusid = 3
)
select
    ngaythuchi::date as ngay,
    ngaythuchi::text as ngaythuchi,
    loaiphieu,
    noidung,
    0 as sotien,
    case when heso = 1 then (heso * sotien) else 0 end as sotien_thu,
    case when heso = -1 then (-heso * sotien) else 0 end as sotien_chi,
    ghichu,
    sophieusothu,
    nguoinopnhan,
    hinhthucthu
from temp_thuchi
where loaiphieu <> 'TDK'
order by ngaythuchi
