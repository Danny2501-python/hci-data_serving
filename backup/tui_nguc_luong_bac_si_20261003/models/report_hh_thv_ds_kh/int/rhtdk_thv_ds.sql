-- Doanh số Tiêu hóa Việt (brand_etl = 8): dịch vụ + nhà thuốc từ
-- report_thv_revenue, đổi nguon_doanh_thu sang 'Dịch vụ'/'Nhà thuốc'.

select
    8                                   as brand_etl,
    'Tiêu hóa Việt'::text               as ten_thuong_hieu,
    case r.nguon_doanh_thu
        when 'dich_vu'   then 'Dịch vụ'
        when 'nha_thuoc' then 'Nhà thuốc'
        else r.nguon_doanh_thu
    end                                 as nguon_du_lieu,
    null::text                          as loai_chi_tieu,
    r.invoicedate,
    r.sotienphieu,
    r.loaiphieu,
    r.sophieu,
    r.invoiceremark,
    null::text                          as pl,
    r.id_booking,
    r.patientrecordid,
    p.patientcode::text                 as patientcode,
    r.patientname,
    r.patientphone,
    null::integer                       as invoiceid,
    r.source_ehc,
    r.dm_hoahongnguoigioithieu_nguoigioithieuname,
    r.nhom_nguon_baocao,
    r.nhom_md_ml_baocao,
    r.erp_old_source_id                 as erp_source_id_old,
    r.erp_old_source_name::text         as old_source_name,
    r.erp_new_source_id                 as erp_source_id_new,
    r.erp_new_source_name::text         as new_source_name,
    r.nguon_sau_mapping::text           as nguon_sau_mapping,
    null::text                          as roomname,
    null::text                          as roomname_kb,
    null::text                          as bac_si,
    null::text                          as loai_phau_thuat
from {{ ref('report_thv_revenue') }} r
-- Lấy mã KH (patientcode) từ hồ sơ EHC THV; patientrecordid unique ở bảng
-- này nên không nhân dòng.
left join {{ source('rtr_base', 'ehc_tb_patientrecord_thv') }} p
    on p.patientrecordid = r.patientrecordid
