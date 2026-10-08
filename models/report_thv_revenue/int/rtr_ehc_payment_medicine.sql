-- Doanh thu nhà thuốc (THV), cột đặt tên tương ứng với rtr_ehc_payment_service
-- (source_ehc/id_booking/invoicedate/sotienphieu/invoiceremark/loaiphieu/sophieu/
-- patientphone/patientname/patientrecordid) để 2 model có thể union/so sánh sau
-- này. loaiphieu chỉ có 1 giá trị thật (type=1) — theo đúng cách cũ của
-- view_thuchi1 cho nhánh tb_invoicemedicine, không có logic đảo dấu hoàn
-- tiền/hoàn ứng như bên invoice chính (chưa xác nhận nhà thuốc có phát sinh
-- loại phiếu hoàn/huỷ khác type=1 hay không).
--
-- patientname ở đây lấy từ ehc_tb_medicinebill_thv.khachlename (tên khách mua
-- thuốc), KHÔNG phải ehc_tb_patientrecord_thv.patientname như bên service —
-- join qua medicinebillid (1-1, an toàn), không dùng patientrecordid vì 1
-- patientrecordid có thể ứng nhiều dòng medicinebill (fan-out).
--
-- nhom_nguon_baocao_ehc/nhom_md_ml_baocao_ehc lấy từ model dùng chung
-- rtr_nhom_nguoigioithieu (cùng rule với rtr_ehc_payment_service, không lặp
-- code CASE ở đây nữa). Hậu tố "_ehc" vì đây là nhóm tính riêng theo dữ liệu
-- EHC — bản cuối cùng (có đối chiếu ERP) nằm ở rtr_combine, cột không có hậu tố.
--
-- FALLBACK người giới thiệu khi hồ sơ của phiếu không ra nguoigioithieuid
-- (patientrecordid = 0 / hồ sơ không gán người giới thiệu — lỗi liên kết ở
-- nguồn, vd BÙI THỊ HẰNG NGA/BÙI TUẤN MẠNH...): lấy tên (khachlename) + SĐT
-- (khachle_phone) của khách mua thuốc, tìm các hồ sơ trùng CẢ tên LẪN SĐT
-- (ehc_tb_patientrecord_thv), lấy người giới thiệu của lần dùng DỊCH VỤ ĐẦU
-- TIÊN (phiếu ehc_tb_invoice_thv sớm nhất, không huỷ, hồ sơ có người giới
-- thiệu) = nguồn đầu tiên đưa khách tới. KHÔNG khớp theo tên thuần (trùng tên
-- chưa chắc cùng 1 người — theo yêu cầu người dùng). Không có SĐT / không
-- khớp / khách chưa từng dùng dịch vụ -> NULL (Thuốc bán lẻ).

with base as (
    select
        i.invoicemedicineid,
        i.medicinebillid,
        i.patientrecordid,
        i.sotienphieu,
        i.invoicemedicinedate,
        i.invoicemedicineremark,
        i.invoicemedicinegroupcode,
        i.invoicemedicinestt,
        i.dm_invoice_typeid,
        mb.khachlename,
        nullif(mb.khachle_phone, '') as khachle_phone
    from {{ source('rtr_base', 'ehc_tb_invoicemedicine_thv') }} i
    left join {{ source('rtr_base', 'ehc_tb_medicinebill_thv') }} mb
           on mb.medicinebillid = i.medicinebillid
    where i.huyphieu_status = 0
),

pr_direct as (
    select
        base.invoicemedicineid,
        pr.nguoigioithieuid,
        pr.id_booking,
        pr.patientphone
    from base
    left join {{ source('rtr_base', 'ehc_tb_patientrecord_thv') }} pr
           on pr.patientrecordid = base.patientrecordid
),

need_fallback as (
    select base.invoicemedicineid, base.khachlename, base.khachle_phone
    from base
    join pr_direct on pr_direct.invoicemedicineid = base.invoicemedicineid
    where pr_direct.nguoigioithieuid is null
      and base.khachle_phone is not null
),

-- Nguồn của lần dùng dịch vụ đầu tiên theo (tên, SĐT): 1 dòng / cặp tên-SĐT.
first_service_ngt as (
    select distinct on (pr.patientname, pr.patientphone)
        pr.patientname,
        pr.patientphone,
        pr.nguoigioithieuid
    from {{ source('rtr_base', 'ehc_tb_invoice_thv') }} iv
    join {{ source('rtr_base', 'ehc_tb_patientrecord_thv') }} pr
      on pr.patientrecordid = iv.patientrecordid
    where iv.huyphieu_status = 0
      and pr.nguoigioithieuid is not null
      and nullif(pr.patientphone, '') is not null
    order by pr.patientname, pr.patientphone, iv.invoicedate, iv.invoiceid
),

fallback as (
    select nf.invoicemedicineid, fs.nguoigioithieuid
    from need_fallback nf
    join first_service_ngt fs
      on fs.patientname = nf.khachlename
     and fs.patientphone = nf.khachle_phone
),

resolved as (
    select
        pr_direct.invoicemedicineid,
        coalesce(pr_direct.nguoigioithieuid, fb.nguoigioithieuid) as nguoigioithieuid,
        pr_direct.id_booking,
        pr_direct.patientphone
    from pr_direct
    left join fallback fb on fb.invoicemedicineid = pr_direct.invoicemedicineid
),

a as (
    select
        resolved.nguoigioithieuid,
        ng.nguoigioithieuname as source_ehc,
        resolved.id_booking,
        date(base.invoicemedicinedate) as invoicedate,
        base.sotienphieu,
        base.invoicemedicineremark as invoiceremark,
        case base.dm_invoice_typeid
            when 1 then 'Thu tiền nhà thuốc'
            else 'Chưa xác định'
        end as loaiphieu,
        concat(base.invoicemedicinegroupcode, '/', base.invoicemedicinestt) as sophieu,
        resolved.patientphone,
        base.khachlename as patientname,
        base.patientrecordid,
        ng.nguoigioithieuremark,
        ng.nguoigioithieuaddress,
        ngg.dm_hoahongnguoigioithieu_nguoigioithieuid,
        ngg.dm_hoahongnguoigioithieu_nguoigioithieuname,
        ngg.nhom_nguon_baocao as nhom_nguon_baocao_ehc,
        ngg.nhom_md_ml_baocao as nhom_md_ml_baocao_ehc
    from base
    join resolved on resolved.invoicemedicineid = base.invoicemedicineid
    left join {{ source('rtr_base', 'ehc_tb_nguoigioithieu_thv') }} ng
           on ng.nguoigioithieuid = resolved.nguoigioithieuid
    left join {{ ref('rtr_nhom_nguoigioithieu') }} ngg
           on ng.nguoigioithieuid = ngg.nguoigioithieuid
)
select * from a
