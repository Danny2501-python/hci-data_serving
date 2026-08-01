Câu query của các báo cáo hệ thống EHC, khi kéo về DWH, các bảng được bổ sung đầu ehc_
1.Báo cáo:Tổng doanh thu của những BN được chỉ định DV từ phòng khám PTTM (ID: 94)
with temp as(
select invoicedate,patientrecordid,
case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end as sotienphieu,
huyphieu_status, dm_invoice_typeid from tb_invoice 
where invoicedate >= '2026-05-01 00:00:00' and invoicedate <= '2026-05-31 23:59:59'
and huyphieu_status =0
and invoiceid not in (select invoiceid from tb_invoicerequest)
)
select sotienphieu, invoicedate,
(select patientcode from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select tongnguonkhac from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select patientname from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select nguoigioithieuname from tb_nguoigioithieu where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid = temp.patientrecordid)),
(select dm_hoahongnguoigioithieu_nguoigioithieuname from tb_dm_hoahongnguoigioithieu_nguoigioithieu 
 where dm_hoahongnguoigioithieu_nguoigioithieuid = (select dm_hoahongnguoigioithieu_nguoigioithieuid from tb_nguoigioithieu 
  where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid=temp.patientrecordid )))

from temp where
patientrecordid in (select patientrecordid from tb_servicedata where  roomid = 94 or do_roomid  = 94 )
-------------------------------
Báo cáo: Tổng doanh thu của những BN có nguồn thuộc nhóm CN - Thuê phòng mổ (ID: 10)
with temp as(
select invoicedate, patientrecordid,
case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end as sotienphieu,
huyphieu_status, dm_invoice_typeid from tb_invoice 
where invoicedate >=  '2026-07-01 00:00:00' and invoicedate <= '2026-07-01 23:59:59'
and huyphieu_status =0
and invoiceid not in (select invoiceid from tb_invoicerequest)
)
select sotienphieu, invoicedate,
(select patientcode from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select patientname from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select tongnguonkhac from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select nguoigioithieuname from tb_nguoigioithieu where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid = temp.patientrecordid)),
(select dm_hoahongnguoigioithieu_nguoigioithieuname from tb_dm_hoahongnguoigioithieu_nguoigioithieu 
 where dm_hoahongnguoigioithieu_nguoigioithieuid = (select dm_hoahongnguoigioithieu_nguoigioithieuid from tb_nguoigioithieu 
  where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid=temp.patientrecordid )))
from temp where
 
patientrecordid in 
(select patientrecordid from tb_patientrecord where nguoigioithieuid in (select nguoigioithieuid from tb_nguoigioithieu where dm_hoahongnguoigioithieu_nguoigioithieuid=26))

---------------------------
Tổng doanh thu của những BN được chỉ định DV từ phòng khám LGBT (ID: 276)
"with temp as(
select invoicedate,patientrecordid,
case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end as sotienphieu,
huyphieu_status, dm_invoice_typeid from tb_invoice 
where invoicedate >= '2026-07-01 00:00:00' and invoicedate <= '2026-07-01 23:59:59'
and huyphieu_status =0
and invoiceid not in (select invoiceid from tb_invoicerequest)
)
select sotienphieu, invoicedate,
(select patientcode from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select tongnguonkhac from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select patientname from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select nguoigioithieuname from tb_nguoigioithieu where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid = temp.patientrecordid)),
(select dm_hoahongnguoigioithieu_nguoigioithieuname from tb_dm_hoahongnguoigioithieu_nguoigioithieu 
 where dm_hoahongnguoigioithieu_nguoigioithieuid = (select dm_hoahongnguoigioithieu_nguoigioithieuid from tb_nguoigioithieu 
  where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid=temp.patientrecordid )))


from temp where
patientrecordid in (select patientrecordid from tb_servicedata where  roomid = 276 or do_roomid  = 276 )"
----------------------------------------
Tỏng doanh thu của những BN ở phòng khám sản trừ những BN IVF (Mã: SA_TIENIVF01)
"with temp as(
select invoicedate,patientrecordid,
case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end as sotienphieu,
huyphieu_status, dm_invoice_typeid from tb_invoice 
where invoicedate >= '2026-07-01 00:00:00' and invoicedate <= '2026-07-29 23:59:59'
and huyphieu_status =0
and invoiceid not in (select invoiceid from tb_invoicerequest)
)
select sotienphieu, invoicedate,
(select patientcode from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select tongnguonkhac from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select patientname from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select nguoigioithieuname from tb_nguoigioithieu where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid = temp.patientrecordid)),
(select dm_hoahongnguoigioithieu_nguoigioithieuname from tb_dm_hoahongnguoigioithieu_nguoigioithieu 
 where dm_hoahongnguoigioithieu_nguoigioithieuid = (select dm_hoahongnguoigioithieu_nguoigioithieuid from tb_nguoigioithieu 
  where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid=temp.patientrecordid )))


from temp where
patientrecordid in (select patientrecordid from tb_servicedata where  roomid in (142, 211) or do_roomid  in (142, 211))
and patientrecordid not in (select patientrecordid from tb_servicedata where servicecode = 'KHAM_TIENIVF01' or  servicecode ='SA_TIENIVF01' or  servicecode ='GOI_IVF01'or  servicecode ='GOI_IVF03'or  servicecode ='GOI_IVF02' )"
--------------------------------
Tỏng doanh thu của những BN được chỉ định dịch vụ Siêu âm đầu dò lần 1 [Gói tiền IVF] (Mã DV: SA_TIENIVF01)
"with temp as(
select invoicedate,patientrecordid,
case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end as sotienphieu,
huyphieu_status, dm_invoice_typeid from tb_invoice 
where invoicedate >= '2026-07-01 00:00:00' and invoicedate <= '2026-07-29 23:59:59'
and huyphieu_status =0
and invoiceid not in (select invoiceid from tb_invoicerequest)
)
select sotienphieu, invoicedate,
(select patientcode from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select tongnguonkhac from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select patientname from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select nguoigioithieuname from tb_nguoigioithieu where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid = temp.patientrecordid)),
(select dm_hoahongnguoigioithieu_nguoigioithieuname from tb_dm_hoahongnguoigioithieu_nguoigioithieu 
 where dm_hoahongnguoigioithieu_nguoigioithieuid = (select dm_hoahongnguoigioithieu_nguoigioithieuid from tb_nguoigioithieu 
  where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid=temp.patientrecordid )))


from temp
where patientrecordid in (select patientrecordid from tb_servicedata where servicecode = 'KHAM_TIENIVF01' or  servicecode ='SA_TIENIVF01' or  servicecode ='GOI_IVF01' or  servicecode ='GOI_IVF03'or  servicecode = 'GOI_IVF02' or dm_servicesubgroupid =10004 )"
---------------------------------------
Tổng doanh thu của những BN được chỉ định DV từ phòng khám Ung Bướu (ID: 92)
"with temp as(
select invoicedate,patientrecordid,
case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end as sotienphieu,
huyphieu_status, dm_invoice_typeid from tb_invoice 
where invoicedate >= '2026-07-01 00:00:00' and invoicedate <= '2026-07-29 23:59:59'
and huyphieu_status =0
and invoiceid not in (select invoiceid from tb_invoicerequest)
)
select sotienphieu, invoicedate,
(select patientcode from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select tongnguonkhac from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select patientname from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select nguoigioithieuname from tb_nguoigioithieu where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid = temp.patientrecordid)),
(select dm_hoahongnguoigioithieu_nguoigioithieuname from tb_dm_hoahongnguoigioithieu_nguoigioithieu 
 where dm_hoahongnguoigioithieu_nguoigioithieuid = (select dm_hoahongnguoigioithieu_nguoigioithieuid from tb_nguoigioithieu 
  where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid=temp.patientrecordid )))

from temp where
patientrecordid in (select patientrecordid from tb_servicedata where  roomid = 92 or do_roomid  = 92 )"
----------------------------------------
Tổng doanh thu của những BN được khám ở những chuyên khoa khác không thuộc những điều kiện trên
"with temp as(
select invoicedate, patientrecordid,
case dm_invoice_typeid when 1 then sotienphieu when 2 then -sotienphieu end as sotienphieu,
huyphieu_status, dm_invoice_typeid from tb_invoice 
where invoicedate >=  '2026-07-01 00:00:00' 
and invoicedate <= '2026-07-29 23:59:59'
and huyphieu_status =0
and invoiceid not in (select invoiceid from tb_invoicerequest)
)
select sotienphieu, invoicedate,
(select patientcode from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select tongnguonkhac from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select patientname from tb_patientrecord where patientrecordid = temp.patientrecordid),
(select nguoigioithieuname from tb_nguoigioithieu where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid = temp.patientrecordid)),
(select dm_hoahongnguoigioithieu_nguoigioithieuname from tb_dm_hoahongnguoigioithieu_nguoigioithieu 
 where dm_hoahongnguoigioithieu_nguoigioithieuid = (select dm_hoahongnguoigioithieu_nguoigioithieuid from tb_nguoigioithieu 
  where nguoigioithieuid = (select nguoigioithieuid from tb_patientrecord where patientrecordid=temp.patientrecordid )))
 
from temp where
patientrecordid not in 
(select patientrecordid from tb_patientrecord where nguoigioithieuid in (select nguoigioithieuid from tb_nguoigioithieu where dm_hoahongnguoigioithieu_nguoigioithieuid=26))
and patientrecordid not in (select patientrecordid from tb_servicedata where  roomid in (92,94, 211,142, 276,262) or do_roomid in (92,94, 211,142, 276,262) )"
