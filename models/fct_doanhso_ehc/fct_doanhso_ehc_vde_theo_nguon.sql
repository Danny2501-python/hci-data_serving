-- Bản sao của fct_doanhso_ehc_theo_nguon.sql cho brand Tiêu Hóa Việt (VDE) —
-- cùng logic hệt nhau, chỉ đổi sang các bảng nguồn hậu tố _thv (xem LOGIC.md
-- mục "Biến thể _thv" — _thv = instance HIS riêng của VDE, không phải brand_etl).
{{ config(materialized='table') }}

with inv as (
    select
        invoiceid,
        patientrecordid,
        invoicedate,
        case dm_invoice_typeid
            when 1 then sotienphieu
            when 2 then -sotienphieu
        end as sotien_thuc
    from {{ source('ehc', 'ehc_tb_invoice_thv') }}
    where huyphieu_status = 0
        and invoiceid not in (
            select invoiceid from {{ source('ehc', 'ehc_tb_invoicerequest_thv') }}
        )
),
pr as (
    select patientrecordid, patientcode, patientname, nguoigioithieuid
    from {{ source('ehc', 'ehc_tb_patientrecord_thv') }}
),
ng as (
    select nguoigioithieuid, nguoigioithieuname, dm_hoahongnguoigioithieu_nguoigioithieuid
    from {{ source('ehc', 'ehc_tb_nguoigioithieu_thv') }}
),
nhom_ng as (
    select dm_hoahongnguoigioithieu_nguoigioithieuid, dm_hoahongnguoigioithieu_nguoigioithieuname
    from {{ source('ehc', 'ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu_thv') }}
)
select
    inv.invoiceid as ma_phieu,
    pr.patientcode as ma_benh_nhan,
    pr.patientname as ten_benh_nhan,
    inv.sotien_thuc as so_tien_phieu,
    inv.invoicedate as ngay_thu,
    ng.nguoigioithieuname as nguon,
    nhom_ng.dm_hoahongnguoigioithieu_nguoigioithieuname as nhom_nguon_khach
from inv
left join pr on pr.patientrecordid = inv.patientrecordid
left join ng on ng.nguoigioithieuid = pr.nguoigioithieuid
left join nhom_ng on nhom_ng.dm_hoahongnguoigioithieu_nguoigioithieuid = ng.dm_hoahongnguoigioithieu_nguoigioithieuid
