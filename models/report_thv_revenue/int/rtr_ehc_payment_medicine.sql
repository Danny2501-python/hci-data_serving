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
-- FALLBACK người giới thiệu khi ehc_tb_invoicemedicine_thv.patientrecordid = 0
-- (lỗi liên kết ở nguồn — xác nhận qua vd BÙI THỊ HẰNG NGA/BÙI TUẤN MẠNH...:
-- có hồ sơ bệnh nhân + người giới thiệu hợp lệ ở chỗ khác, nhưng riêng phiếu
-- này không được gán patientrecordid). Áp dụng 2 tầng, chỉ nhận khi KHÔNG mơ
-- hồ (unique candidate) — thà để NULL còn hơn gán nhầm referrer:
--   1. Khớp tên (khachlename) + số điện thoại (khachle_phone = patientphone)
--      với ehc_tb_patientrecord_thv, ra đúng 1 nguoigioithieuid.
--   2. Không có số điện thoại (hoặc không khớp) -> khớp theo tên, CHỈ nhận
--      nếu mọi hồ sơ trùng tên đều cùng 1 nguoigioithieuid (nhiều người
--      trùng tên — vd "NGUYỄN THỊ HUYỀN" có tới 9 người giới thiệu khác nhau
--      — sẽ bị bỏ qua, không đoán).
-- Verify: giải quyết được 30/50 dòng "không nguồn" của tháng 8 theo cách này.

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
),

phone_match_dedup as (
    select invoicemedicineid, min(nguoigioithieuid) as nguoigioithieuid, count(distinct nguoigioithieuid) as n_candidate
    from (
        select nf.invoicemedicineid, pr.nguoigioithieuid
        from need_fallback nf
        join {{ source('rtr_base', 'ehc_tb_patientrecord_thv') }} pr
               on pr.patientname = nf.khachlename
              and pr.patientphone = nf.khachle_phone
        where nf.khachle_phone is not null
        group by nf.invoicemedicineid, pr.nguoigioithieuid
    ) t
    group by invoicemedicineid
),

name_match_dedup as (
    select invoicemedicineid, min(nguoigioithieuid) as nguoigioithieuid, count(distinct nguoigioithieuid) as n_candidate
    from (
        select nf.invoicemedicineid, pr.nguoigioithieuid
        from need_fallback nf
        join {{ source('rtr_base', 'ehc_tb_patientrecord_thv') }} pr
               on pr.patientname = nf.khachlename
        group by nf.invoicemedicineid, pr.nguoigioithieuid
    ) t
    group by invoicemedicineid
),

resolved as (
    select
        pr_direct.invoicemedicineid,
        coalesce(
            pr_direct.nguoigioithieuid,
            case when pmd.n_candidate = 1 then pmd.nguoigioithieuid end,
            case when nmd.n_candidate = 1 then nmd.nguoigioithieuid end
        ) as nguoigioithieuid,
        pr_direct.id_booking,
        pr_direct.patientphone
    from pr_direct
    left join phone_match_dedup pmd on pmd.invoicemedicineid = pr_direct.invoicemedicineid
    left join name_match_dedup nmd on nmd.invoicemedicineid = pr_direct.invoicemedicineid
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
