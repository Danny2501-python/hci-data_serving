-- Doanh số + mục tiêu Hồng Hà (brand_etl = 4), lấy nguyên từ
-- rhh_ehc_payment_service (đã có sẵn Dịch vụ + Nhà thuốc + Target từ
-- ggs_target_company brand_id = 4). Target gán loai_chi_tieu = 'ds'.
--
-- nhom_md_ml_baocao: gom theo nhóm hoa hồng EHC của HH
-- (dm_hoahongnguoigioithieu_nguoigioithieuname) — KHÔNG dùng nguyên rule tên
-- của THV (rtr_nhom_nguoigioithieu) vì vocab HH khác: nhóm "Marketing"/
-- "[MAR_ON]MKT Online" (Facebook, Hotline...) sẽ bị rule THV đẩy sang ML.
-- Thứ tự ưu tiên:
--   0. Khoản trừ 'Túi ngực/mông' / 'Lương bác sĩ' -> ML (thuộc thuê phòng mổ,
--      người dùng chốt 2026-09-29)
--   1. [TPM]Thuê phòng mổ                          -> ML (mục tiêu "Nguồn Offline"
--      của HH gồm cả thuê phòng mổ — yêu cầu người dùng)
--   2. tên chứa "CBNV" và không chứa "CTV"          -> CBNV
--   3. tên chứa "Vãng lai"                         -> MD, từ T9/2026 -> ML (giống THV)
--   4. [MO] / [MAR_OFF] / Trade Marketing          -> MO (giống THV tách MO)
--   5. Marketing / [MAR_ON] / [MD] / [DGMKT]       -> MD
--   6. không có cả nhóm lẫn người giới thiệu       -> NULL (không đoán);
--      riêng Nhà thuốc từ T9/2026 -> ML (Thuốc bán lẻ, giống THV)
--   7. còn lại (CTV, giới thiệu, loyalty, [ML]...) -> ML

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
    case
        when e.nguon_du_lieu = 'Target' then null
        when e.nguon_du_lieu in ('Túi ngực/mông', 'Lương bác sĩ') then 'ML'
        when e.dm_hoahongnguoigioithieu_nguoigioithieuname ilike '[TPM]%' then 'ML'
        when e.source_ehc ilike '%CBNV%' and e.source_ehc not ilike '%CTV%' then 'CBNV'
        when e.source_ehc ilike '%Vãng lai%' then
            case when e.invoicedate >= date '2026-09-01' then 'ML' else 'MD' end
        when e.dm_hoahongnguoigioithieu_nguoigioithieuname ilike '[MO]%'
          or e.dm_hoahongnguoigioithieu_nguoigioithieuname ilike '[MAR_OFF]%'
          or e.dm_hoahongnguoigioithieu_nguoigioithieuname = 'Trade Marketing' then 'MO'
        when e.dm_hoahongnguoigioithieu_nguoigioithieuname = 'Marketing'
          or e.dm_hoahongnguoigioithieu_nguoigioithieuname ilike '[MAR_ON]%'
          or e.dm_hoahongnguoigioithieu_nguoigioithieuname ilike '[MD]%'
          or e.dm_hoahongnguoigioithieu_nguoigioithieuname ilike '[DGMKT]%' then 'MD'
        when e.dm_hoahongnguoigioithieu_nguoigioithieuname is null
         and e.source_ehc is null
         and e.nguon_du_lieu = 'Nhà thuốc'
         and e.invoicedate >= date '2026-09-01' then 'ML'
        when e.dm_hoahongnguoigioithieu_nguoigioithieuname is null
         and e.source_ehc is null then null
        else 'ML'
    end::text                           as nhom_md_ml_baocao,
    e.erp_source_id_old,
    e.old_source_name::text             as old_source_name,
    e.erp_source_id_new,
    e.new_source_name::text             as new_source_name,
    null::text                          as nguon_sau_mapping,
    e.roomname,
    e.roomname_kb,
    e.bac_si,
    e.loai_phau_thuat
from {{ ref('rhh_ehc_payment_service') }} e
