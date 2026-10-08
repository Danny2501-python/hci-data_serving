-- Pass 4 (lead_data): booking crm_lead active. type_crm_id = 3 chỉ lấy booking
-- có crm_line với initial_product_id null hoặc <> 0. Mỗi (brand_etl, booking) 1 dòng.
-- Join theo brand_etl (id crm_lead chỉ duy nhất trong 1 brand_etl).
-- Chỉ lấy booking có ngày tạo lead ERP (giờ VN) từ var sdr_lead_start_date (mặc định
-- 2026-05-01): dữ liệu ERP tách brand mới đủ từ mốc này; thanh toán cũ brand_etl = 0
-- (trước 08/2025) không join được theo brand_etl nên tự loại.

with a as (
    select
        date(cl.create_date + '07:00:00'::interval) create_date,
        date(cl.arrival_date + '07:00:00'::interval) arrival_date,
        rp.code_customer,
        rp."name" "contact_name",
        cl.name booking,
        cl.id,
        cl.type_crm_id,
        cs.name stage_bk,
        cl.company_id company_id_bk,
        cl.brand_id as brand_id_bk,
        uc.name campaign,
        cl.brand_etl
    from (select * from {{ source('sdr_base', 'crm_lead') }} cl where cl.type_crm_id not in (1, 3) and cl.active is true and date(cl.create_date + '07:00:00'::interval) >= '{{ var("sdr_lead_start_date", "2026-05-01") }}'::date) cl
    left join {{ source('sdr_base', 'crm_stage') }} cs on cl.stage_id = cs.id and cs.brand_etl = cl.brand_etl
    left join {{ source('sdr_base', 'res_partner') }} rp on rp.id = cl.partner_id and rp.brand_etl = cl.brand_etl
    left join {{ source('sdr_base', 'utm_campaign') }} uc on uc.id = cl.campaign_id and uc.brand_etl = cl.brand_etl
    union all
    select
        date(cl.create_date + '07:00:00'::interval) create_date,
        date(cl.arrival_date + '07:00:00'::interval) arrival_date,
        rp.code_customer,
        rp."name" "contact_name",
        cl.name booking,
        cl.id,
        cl.type_crm_id,
        cs.name stage_bk,
        cl.company_id company_id_bk,
        cl.brand_id as brand_id_bk,
        uc.name campaign,
        cl.brand_etl
    from (select * from {{ source('sdr_base', 'crm_lead') }} cl where cl.type_crm_id = 3 and cl.active is true and date(cl.create_date + '07:00:00'::interval) >= '{{ var("sdr_lead_start_date", "2026-05-01") }}'::date) cl
    left join {{ source('sdr_base', 'crm_line') }} cl2 on cl2.crm_id = cl.id and cl2.brand_etl = cl.brand_etl
    left join {{ source('sdr_base', 'crm_stage') }} cs on cl.stage_id = cs.id and cs.brand_etl = cl.brand_etl
    left join {{ source('sdr_base', 'res_partner') }} rp on rp.id = cl.partner_id and rp.brand_etl = cl.brand_etl
    left join {{ source('sdr_base', 'utm_campaign') }} uc on uc.id = cl.campaign_id and uc.brand_etl = cl.brand_etl
    where (cl2.initial_product_id is null or cl2.initial_product_id <> 0) and cl2.crm_id is not null
),
b as (
    select a.*, row_number() over (partition by a.brand_etl, a.id) rnk_bk from a
)
select * from b where b.rnk_bk = 1
