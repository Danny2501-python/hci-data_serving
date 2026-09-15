-- Lead/booking CRM (THV, brand_etl = 8) — dùng để lấy nguồn booking trên ERP
-- theo lead_booking (map với id_booking bên EHC qua rtr_ehc_payment_service/
-- medicine). Base giống hệt tso_lead.sql của report_thv_sale_online.
--
-- old_source_name/new_source_name lấy qua m_utm_source_old_new_map
-- (brand_etl = 8, đã xác nhận có dữ liệu — xem models/master_data):
--   - old_source_id (map) join source_id (crm_lead)      -> 1-1, an toàn
--   - new_source_id (map) join new_source_id (crm_lead)  -> new_source_id
--     KHÔNG unique trong map (nhiều old gộp về 1 new, xem comment gốc của
--     m_utm_source_old_new_map) nên phải dedup (distinct new_source_id,
--     new_source_name) trước khi join, tránh fan-out. Đã verify: mỗi
--     new_source_id chỉ ứng đúng 1 new_source_name (brand_etl = 8).

with lead as (
    select
        id,
        name lead_booking,
        create_uid,
        source_id,
        new_source_id,
        date(create_date + '7 hour') create_date,
        date(arrival_date + '7 hour') arrival_date,
        date(booking_date + '7 hour') booking_date,
        create_by_department,
        type_data_partner,
        overseas_vietnamese,
        code_customer,
        contact_name,
        phone,
        ticket_id,
        stage_id,
        company_id,
        state_id,
        type,
        type_crm_id,
        customer_come,
        reason_cancel_booking
    from {{ source('rtr_base', 'crm_lead') }}
    where brand_etl = 8 and active = true
),

utm_map as (
    select *
    from {{ ref('m_utm_source_old_new_map') }}
    where brand_etl = 8
),

old_map as (
    select distinct old_source_id, old_source_name
    from utm_map
),

new_map as (
    select distinct new_source_id, new_source_name
    from utm_map
)

select
    lead.*,
    old_map.old_source_name,
    new_map.new_source_name
from lead
left join old_map on old_map.old_source_id = lead.source_id
left join new_map on new_map.new_source_id = lead.new_source_id
