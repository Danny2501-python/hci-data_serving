-- Doanh thu dịch vụ (HH), gộp doanh thu chính (ds) + khoản cọc (dc), theo
-- code gốc người dùng cung cấp. Model nền dùng chung cho các model tính
-- doanh số cụ thể phía sau (rhh_doanh_so_tpm, rhh_doanh_so_pttm...), không
-- lặp lại code ds/dc ở từng model con.
--
-- ds: doanh thu từ ehc_tb_invoice, loại trừ các invoiceid đã nằm trong
-- ehc_tb_invoicerequest (để không đếm trùng với phần cọc dc).
-- dc: khoản cọc từ ehc_tb_invoicerequest.
--
-- Join nhóm hoa hồng người giới thiệu (dm_hoahongnguoigioithieu_nguoigioithieuname)
-- qua dm_hoahongnguoigioithieu_nguoigioithieuid = ...id (ĐÃ VERIFY: không dùng
-- ...dbid — join theo dbid cho kết quả sai, vd nhóm id=2 ra "Bảo hiểm y tế"
-- thay vì đúng phải là "BP Kinh Doanh").
--
-- roomid lấy theo iv.roomid (ds) / mặc định 0 (dc, vì ehc_tb_invoicerequest
-- không có cột roomid riêng) — phòng của TỪNG PHIẾU. roomid_kb lấy từ
-- ehc_tb_patientrecord — phòng khám gán cho hồ sơ bệnh nhân đó (patientrecordid),
-- không đổi theo từng phiếu như roomid. CHỈ để tham khảo/lọc thô, KHÔNG dùng
-- riêng 1 trong 2 cột để xác định khách thuộc phòng nào — đã verify (case
-- LGBT/room 276) có khách CHỈ xuất hiện qua roomid_kb (không phiếu nào có
-- iv.roomid=276 cả) — phải check CẢ HAI (roomid = X or roomid_kb = X), xem
-- rhh_doanh_so_pttm.sql/rhh_doanh_so_lgbt.sql. Ngoài ra 1 khách (patientcode)
-- có thể có nhiều patientrecordid/booking qua các lần khám, mỗi lần 1 cặp
-- roomid/roomid_kb khác nhau — nên bước 2 (cộng doanh thu) phải gộp theo
-- patientcode, không lọc roomid trực tiếp trên kết quả cuối.
--
-- patientcode: mã bệnh nhân ổn định qua nhiều patientrecordid/booking của
-- cùng 1 người — dùng để nhận diện đúng 1 khách hàng thực tế.

with ds as (
    select
        etn.nguoigioithieuname as source_ehc,
        etp.id_booking,
        date(iv.invoicedate) as invoicedate,
        case
            when (dm_invoice_typeid = 4 or dm_invoice_typeid = 2)
                then -sotienphieu else sotienphieu
        end as sotienphieu,
        invoiceremark,
        case
            when dm_invoice_typeid = 1 then 'Phiếu thu'
            when dm_invoice_typeid = 2 then 'Hoàn tiền'
            when dm_invoice_typeid = 3 then 'Tạm ứng'
            when dm_invoice_typeid = 4 then 'Hoàn ứng'
            when dm_invoice_typeid = 5 then 'Miễn giảm'
            when dm_invoice_typeid = 6 then 'Thu 0đ'
            when dm_invoice_typeid = 7 then 'Chi BHYT'
            else 'Chưa rõ'
        end as loaiphieu,
        concat(invoicegroupcode, '/', invoicestt) as sophieu,
        etp.patientphone,
        etp.patientname,
        etp.patientcode,
        iv.patientrecordid,
        iv.invoiceid,
        dgt.dm_hoahongnguoigioithieu_nguoigioithieuname,
        iv.roomid,
        etp.roomid_kb,
        'DT trừ cọc trong tháng' as pl
    from {{ source('rhh_base', 'ehc_tb_invoice') }} iv
    left join {{ source('rhh_base', 'ehc_tb_patientrecord') }} etp
           on iv.patientrecordid = etp.patientrecordid
    left join {{ source('rhh_base', 'ehc_tb_nguoigioithieu') }} etn
           on etp.nguoigioithieuid = etn.nguoigioithieuid
    left join {{ source('rhh_base', 'ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu') }} dgt
           on dgt.dm_hoahongnguoigioithieu_nguoigioithieuid = etn.dm_hoahongnguoigioithieu_nguoigioithieuid
    where huyphieu_status = 0
      and invoiceid not in (select invoiceid from {{ source('rhh_base', 'ehc_tb_invoicerequest') }})
),

dc as (
    select
        etn.nguoigioithieuname as source_ehc,
        etp.id_booking,
        etit.ngayyeucau::date as invoicedate,
        etit.sotien as sotienphieu,
        'Thu tiền' as invoiceremark,
        'Phiếu thu' as loaiphieu,
        etit.payment_code as sophieu,
        etp.patientphone,
        etp.patientname,
        etp.patientcode,
        etit.patientrecordid,
        etit.invoiceid,
        dgt.dm_hoahongnguoigioithieu_nguoigioithieuname,
        0 as roomid,
        etp.roomid_kb,
        'Cọc trong tháng' as pl
    from {{ source('rhh_base', 'ehc_tb_invoicerequest') }} etit
    left join {{ source('rhh_base', 'ehc_tb_patientrecord') }} etp
           on etit.patientrecordid = etp.patientrecordid
    left join {{ source('rhh_base', 'ehc_tb_nguoigioithieu') }} etn
           on etp.nguoigioithieuid = etn.nguoigioithieuid
    left join {{ source('rhh_base', 'ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu') }} dgt
           on dgt.dm_hoahongnguoigioithieu_nguoigioithieuid = etn.dm_hoahongnguoigioithieu_nguoigioithieuid
)

select * from ds
union all
select * from dc
