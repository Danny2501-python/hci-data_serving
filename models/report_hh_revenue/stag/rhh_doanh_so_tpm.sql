-- Doanh số theo NHÓM NGUỒN "[TPM]Thuê phòng mổ" (dm_hoahongnguoigioithieu_
-- nguoigioithieuname) — khác với rhh_doanh_so_pttm.sql (theo PHÒNG vật lý
-- PTTM/room 94). TPM ở đây là nhóm hoa hồng người giới thiệu, lọc trực tiếp
-- trên rhh_ehc_payment_service, không cần logic gom theo patientcode.

select *
from {{ ref('rhh_ehc_payment_service') }}
where dm_hoahongnguoigioithieu_nguoigioithieuname = '[TPM]Thuê phòng mổ'
