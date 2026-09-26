-- Doanh số + mục tiêu Hồng Hà (brand_etl = 4), lấy nguyên từ
-- rhh_ehc_payment_service (đã có sẵn Dịch vụ + Nhà thuốc + Target từ
-- ggs_target_company brand_id = 4). Target gán loai_chi_tieu = 'ds'.

select
    4                                   as brand_etl,
    'Hồng Hà'::text                     as ten_thuong_hieu,
    e.nguon_du_lieu,
    case when e.nguon_du_lieu = 'Target' then 'ds' end as loai_chi_tieu,
    e.invoicedate,
    e.sotienphieu,
    e.loaiphieu,
    e.sophieu,
    e.invoiceremark,
    e.pl,
    e.id_booking,
    e.patientrecordid,
    e.patientcode,
    e.patientname,
    e.patientphone,
    e.invoiceid,
    e.source_ehc,
    e.dm_hoahongnguoigioithieu_nguoigioithieuname,
    null::text                          as nhom_nguon_baocao,
    null::text                          as nhom_md_ml_baocao,
    e.erp_source_id_old,
    e.old_source_name::text             as old_source_name,
    e.erp_source_id_new,
    e.new_source_name::text             as new_source_name,
    null::text                          as nguon_sau_mapping,
    e.roomname,
    e.roomname_kb
from {{ ref('rhh_ehc_payment_service') }} e
