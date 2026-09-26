-- Mục tiêu Tiêu hóa Việt (brand_etl = 8) từ rtr_target_latest. Nhiều loại
-- chỉ tiêu/tháng chồng nhau (ds, md, ml...) — mục tiêu tổng là loai_chi_tieu = 'ds'.

select
    8                                   as brand_etl,
    'Tiêu hóa Việt'::text               as ten_thuong_hieu,
    'Target'::text                      as nguon_du_lieu,
    t.chi_tieu::text                    as loai_chi_tieu,
    t.ngay_dau_thang::date              as invoicedate,
    t.target::double precision          as sotienphieu,
    'Chỉ tiêu'::text                    as loaiphieu,
    null::text                          as sophieu,
    null::text                          as invoiceremark,
    null::text                          as pl,
    null::text                          as id_booking,
    null::integer                       as patientrecordid,
    null::text                          as patientcode,
    null::text                          as patientname,
    null::text                          as patientphone,
    null::integer                       as invoiceid,
    null::text                          as source_ehc,
    null::text                          as dm_hoahongnguoigioithieu_nguoigioithieuname,
    null::text                          as nhom_nguon_baocao,
    null::text                          as nhom_md_ml_baocao,
    null::integer                       as erp_source_id_old,
    null::text                          as old_source_name,
    null::integer                       as erp_source_id_new,
    null::text                          as new_source_name,
    null::text                          as nguon_sau_mapping,
    null::text                          as roomname,
    null::text                          as roomname_kb
from {{ ref('rtr_target_latest') }} t
