-- Danh sách booking Tiêu hóa Việt CÓ DÙNG DỊCH VỤ NỘI SOI (1 dòng / booking),
-- dùng gắn cờ dc_tc_noi_soi ở rhtdk_booking_dc. Logic theo truy vấn "khách
-- nội soi thành công" người dùng cung cấp 2026-10-14 (CTE noi_soi):
--   - dịch vụ EHC THV (ehc_tb_servicedata_thv) tên chứa "nội soi" hoặc
--     "gói tầm soát", soluong > 0;
--   - KHÔNG xét trạng thái dịch vụ (bắt cả dòng gói/combo);
--   - bỏ nhóm thuốc / vật tư (không tính "Giấy in bóng nội soi");
--   - nối booking qua ehc_tb_patientrecord_thv.id_booking (= crm_lead.name).
-- dv_noi_soi: các dịch vụ làm booking được gắn tag (tham khảo).
--
-- materialized = table (khác các model int/ ephemeral khác): để ephemeral thì
-- dbt inline thành CTE trong mart, planner chọn nested loop -> build > 10 phút;
-- tách bảng riêng (~1s) rồi rhtdk_booking_dc join vào thì build mart vài giây.
{{ config(materialized='table') }}

select
    pr.id_booking,
    string_agg(distinct trim(sd.servicename), ' | ') as dv_noi_soi
from {{ source('rtr_base', 'ehc_tb_servicedata_thv') }} sd
join {{ source('rtr_base', 'ehc_tb_patientrecord_thv') }} pr
  on pr.patientrecordid = sd.patientrecordid
left join {{ source('rtr_base', 'ehc_tb_dm_servicegroup_thv') }} g
  on g.dm_servicegroupid = sd.dm_servicegroupid
where (sd.servicename ilike '%nội soi%' or sd.servicename ilike '%gói tầm soát%')
  and sd.soluong > 0
  and coalesce(g.dm_servicegroupname, '') not ilike '%thuốc%'
  and coalesce(g.dm_servicegroupname, '') not ilike '%vật tư%'
  and pr.id_booking is not null
group by pr.id_booking
