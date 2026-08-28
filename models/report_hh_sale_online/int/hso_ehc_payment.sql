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
iv.patientrecordid,
iv.invoiceid as invoiceid,
'DT trừ cọc trong tháng' pl 
from {{source('hh','ehc_tb_invoice')}} iv
left join {{source('hh','ehc_tb_patientrecord')}} etp
on iv.patientrecordid = etp.patientrecordid
left join {{source('hh','ehc_tb_nguoigioithieu')}} etn
 on etp.nguoigioithieuid =etn.nguoigioithieuid
where
  huyphieu_status = 0
  and  invoiceid not in (select invoiceid from ehc_tb_invoicerequest) 
--and  etp.id_booking ='BOOK-260717-00038'
--and date(iv.invoicedate) between '20260601' and '20260630'
),
dc as (
    select
        etn.nguoigioithieuname source_ehc,
        etp.id_booking,
        etit.ngayyeucau::date invoicedate,--invoicedate ngày khách cọc
        etit.sotien sotienphieu,
        'Thu tiền' invoiceremark,
        'Phiếu thu' loaiphieu,
        etit.payment_code sophieu,
        etp.patientphone,
        etp.patientname,
        etit.patientrecordid,
        etit.invoiceid,
        'Cọc trong tháng' pl
    from {{source('hh','ehc_tb_invoicerequest')}} etit
    left join {{source('hh','ehc_tb_patientrecord')}} etp on etit.patientrecordid = etp.patientrecordid
    left join {{source('hh','ehc_tb_nguoigioithieu')}} etn on etp.nguoigioithieuid =etn.nguoigioithieuid
)
select * from ds
union all
select * from dc