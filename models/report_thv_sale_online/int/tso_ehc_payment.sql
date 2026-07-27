with ds as (
    select 
etn.nguoigioithieuname source_ehc, ---nguồn khách hàng
etp.id_booking,
date(iv.invoicedate) invoicedate , --ngày thanh toán
case
	when (dm_invoice_typeid = 4 or dm_invoice_typeid = 2)
Then -sotienphieu else sotienphieu end as
sotienphieu, 
invoiceremark,
---invoicedate,
Case when dm_invoice_typeid = 1 Then 'Phiếu thu'
when dm_invoice_typeid = 2 Then 'Hoàn tiền'
when dm_invoice_typeid = 3 Then 'Tạm ứng'
when dm_invoice_typeid = 4 Then 'Hoàn ứng'
when dm_invoice_typeid = 5 Then 'Miễn giảm'
when dm_invoice_typeid = 6 Then 'Thu 0đ'
when dm_invoice_typeid = 7 Then 'Chi BHYT'
else 'Chưa rõ' end as loaiphieu,
concat(invoicegroupcode,'/',invoicestt) as sophieu,
etp.patientphone ,
etp.patientname ,
iv.patientrecordid
from {{source('thv','ehc_tb_invoice_thv')}} iv
left join {{source('thv','ehc_tb_patientrecord_thv')}} etp  
on iv.patientrecordid = etp.patientrecordid 
left join {{source('thv','ehc_tb_nguoigioithieu_thv')}} etn
 on etp.nguoigioithieuid =etn.nguoigioithieuid 
where 
  huyphieu_status = 0
--and  etp.id_booking ='BOOK-260717-00038'
--and date(iv.invoicedate) between '20260601' and '20260630'
)
select * from ds