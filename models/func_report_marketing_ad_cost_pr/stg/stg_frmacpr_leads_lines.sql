-- =============================================================================
-- stg_frmacpr_leads_lines
-- PASS 1 & 2: Lấy leads và lines của brand Paris (brand_etl = 3).
-- Materialized ephemeral – chỉ dùng nội bộ trong pipeline.
-- =============================================================================
-- Leads
WITH paris_leads AS (
    SELECT
        cl.id,
        cl.ticket_id,
        cl.overseas_vietnamese,
        cl.contact_name,
        cl.code_customer,
        cl.phone,
        cl.arrival_date,
        cl.create_date,
        cl.create_on,
        cl.booking_date,
        cl.name,
        cl.amount_paid,
        cl.type_crm_id,
        cl.type_data_partner,
        cl.type,
        cl.active,
        cl.brand_id,
        cl.company_id,
        cl.campaign_id,
        cl.stage_id,
        cl.department_id,
        cl.source_id,
        cl.new_source_id,
        cl.create_by,
        cl.create_by_department,
        cl.brand_etl,
        cl.state_id,
        cl.country_id
    FROM {{ source('paris', 'crm_lead') }} cl
    WHERE cl.brand_etl = 3
      AND cl.create_by_department IS NOT NULL
),

-- Lines
paris_lines AS (
    SELECT
        id,
        crm_id,
        product_id,
        stage,
        create_date,
        brand_etl,
        total_received
    FROM {{ source('paris', 'crm_line') }}
    WHERE brand_etl = 3
)

-- Expose leads joined with lines so downstream models can filter
SELECT
    l.id                        AS lead_id,
    l.ticket_id,
    l.overseas_vietnamese,
    l.phone,
    l.arrival_date,
    l.create_date,
    l.booking_date,
    l.type_crm_id,
    l.type,
    l.stage_id,
    l.source_id,
    l.new_source_id,
    l.company_id,
    l.brand_etl,
    l.state_id,
    l.country_id,
    ln.product_id,
    ln.total_received,
    ln.stage                    AS line_stage
FROM paris_leads l
LEFT JOIN paris_lines ln ON ln.crm_id = l.id
