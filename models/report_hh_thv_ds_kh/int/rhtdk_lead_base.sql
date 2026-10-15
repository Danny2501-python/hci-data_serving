-- Base crm_lead dùng chung cho 4 bảng rhtdk_sdt / rhtdk_booking_create /
-- rhtdk_booking / rhtdk_booking_dc: Hồng Hà (brand_etl = 4) + Tiêu hóa Việt
-- (brand_etl = 8), type_crm_id 1 (SĐT/lead) và 2 (booking).
-- Các mốc thời gian đổi sang giờ VN (+7h). Chỉ lấy active = true (bỏ lead/
-- booking đã archive, giống rtr_lead).
--
-- Nguồn ERP:
--   - old_source_name: utm_source theo source_id, cùng brand_etl (id
--     utm_source KHÔNG unique giữa các brand -> join kèm brand_etl).
--   - new_source_id: ưu tiên crm_lead.new_source_id; không có thì đổi từ
--     source_id qua m_utm_source_old_new_map (old_source_id unique theo brand
--     -> không nhân dòng). new_source_name lấy từ utm_source cùng brand.
--
-- nhom_md_ml_raw: gom MD/ML theo TÊN NGUỒN CŨ ERP (old_source_name, phủ ~99%;
-- nguồn mới HH mới map được 38 nguồn nên không dùng). Cùng bộ nhóm với doanh
-- số (rhtdk_hh), thứ tự ưu tiên:
--   1. chứa "Cho thuê phòng mổ"                  -> TPM
--   2. chứa "CBNV" hoặc "Đối ngoại"              -> CBNV
--   3. chứa "Vãng lai"                           -> 'VL' (tạm; 4 bảng con đổi
--      thành MD trước T10/2026, ML từ T10/2026 theo ngày của từng bảng)
--   4. bắt đầu "MO - "                           -> MO
--   5. bắt đầu "MD - " hoặc "DG - MD - "         -> MD
--   6. không có nguồn / "Không có nguồn cũ"      -> NULL
--   7. còn lại (ML -, CTV, KH giới thiệu, loyalty, Dr.Giang...) -> ML
--
-- co_line: lead/booking có dịch vụ — chỉ đánh dấu, KHÔNG lọc:
--   - Hồng Hà (4): có nhóm dịch vụ ở crm_lead_product_category_rel
--     (lead_id = crm_lead.id, cùng brand_etl) — HH gần như không ghi
--     crm_line cho lead, chỉ bắt đầu dùng crm_line từ ~T5/2026.
--   - Tiêu hóa Việt (8): có dòng crm_line (crm_id = crm_lead.id, cùng brand_etl).

with lead as (
    select *
    from {{ source('rhh_base', 'crm_lead') }}
    where brand_etl in (4, 8)
      and type_crm_id in (1, 2)
      and active = true
),

utm_map as (
    select brand_etl, old_source_id, new_source_id
    from {{ ref('m_utm_source_old_new_map') }}
    where brand_etl in (4, 8)
),

us as (
    select brand_etl, id, name
    from {{ source('rhh_base', 'utm_source') }}
    where brand_etl in (4, 8)
),

crm_line_ids as (
    select distinct brand_etl, crm_id
    from {{ source('rhh_base', 'crm_line') }}
    where brand_etl = 8
),

category_ids as (
    select distinct brand_etl, lead_id
    from {{ source('crm_base', 'crm_lead_product_category_rel') }}
    where brand_etl = 4
),

src as (
    select
        l.*,
        coalesce(l.new_source_id, m.new_source_id) as new_source_id_map
    from lead l
    left join utm_map m
        on m.brand_etl = l.brand_etl
        and m.old_source_id = l.source_id
)

select
    s.brand_etl,
    case s.brand_etl
        when 4 then 'Hồng Hà'
        when 8 then 'Tiêu hóa Việt'
    end::text                                   as ten_thuong_hieu,
    s.id                                        as lead_id,
    s.name                                      as ma_lead,
    s.type_crm_id,
    s.active,
    s.create_date  + interval '7 hour'          as create_time,
    s.booking_date + interval '7 hour'          as booking_time,
    s.arrival_date + interval '7 hour'          as arrival_time,
    s.phone,
    s.contact_name,
    s.code_customer,
    s.stage_id,
    s.company_id,
    s.source_id                                 as erp_source_id_old,
    us_old.name::text                           as old_source_name,
    s.new_source_id_map                         as erp_source_id_new,
    us_new.name::text                           as new_source_name,
    case
        when us_old.name ilike '%Cho thuê phòng mổ%' then 'TPM'
        when us_old.name ilike '%CBNV%'
          or us_old.name ilike '%Đối ngoại%' then 'CBNV'
        when us_old.name ilike '%Vãng lai%' then 'VL'
        when us_old.name ilike 'MO - %' then 'MO'
        when us_old.name ilike 'MD - %'
          or us_old.name ilike 'DG - MD - %' then 'MD'
        when us_old.name is null
          or us_old.name = 'Không có nguồn cũ' then null
        else 'ML'
    end::text                                   as nhom_md_ml_raw,
    (cli.crm_id is not null or cat.lead_id is not null) as co_line,
    s.amount_paid
from src s
left join us us_old
    on us_old.brand_etl = s.brand_etl
    and us_old.id = s.source_id
left join us us_new
    on us_new.brand_etl = s.brand_etl
    and us_new.id = s.new_source_id_map
left join crm_line_ids cli
    on cli.brand_etl = s.brand_etl
    and cli.crm_id = s.id
left join category_ids cat
    on cat.brand_etl = s.brand_etl
    and cat.lead_id = s.id
