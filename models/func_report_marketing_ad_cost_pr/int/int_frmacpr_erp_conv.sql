-- =============================================================================
-- int_frmacpr_erp_conv
-- PASS 9–13: Lead, BK, BKHL, DC, TC từ dữ liệu CRM Paris.
-- Sử dụng lại stg_frmacpr_leads_lines làm base, join thêm metadata.
-- =============================================================================
WITH base AS (
    SELECT
        CASE
            WHEN (ss2.org_source ilike '%display%' OR ss2.org_source ilike '%search%') AND ctsda.utm_source ilike '%Google_Search%' THEN 'MD - GoogleAds'
            ELSE ss2.org_source
        END                                                         AS nguon,
        ss2.org_category_code                                       AS nhom_nguon,
        CASE
            WHEN ss2.org_source LIKE '%Facebook%' THEN 'FB'
            WHEN ss2.org_source LIKE '%Seo%'      THEN 'Web'
            WHEN (ss2.org_source ilike '%display%' OR ss2.org_source ilike '%search%') AND ctsda.utm_source ilike '%Google_Search%' THEN 'Google'
            WHEN ss2.org_source LIKE '%Hotline%'  THEN 'Web'
            WHEN ss2.org_source LIKE '%Tiktok%'   THEN 'TikTok'
            ELSE 'Khác'
        END                                                         AS kenh,
        ll.lead_id,
        ll.arrival_date,
        ll.create_date,
        ll.booking_date,
        ll.overseas_vietnamese,
        ll.company_id,
        ll.phone,
        ll.type_crm_id,
        ll.type,
        ll.product_id,
        ll.total_received,
        ll.stage_id,
        ll.brand_etl,
        TRIM(mndap.nhom_dv_cpo)                                    AS nhom_dv,
        CASE
            WHEN ll.overseas_vietnamese = 'marketing' THEN 'Việt Kiều '
            ELSE mrc.name
        END                                                         AS chi_nhanh,
        ecs.name                                                    AS stage_name,
        substring(cta.requester FROM '"phone_no":\s*"(\d+)"') AS phone_no_ticket
    FROM {{ ref('stg_frmacpr_leads_lines') }}               ll
    LEFT JOIN {{ source('paris', 'cs_ticket_api')}}                cta
        ON cta.ticket_id = ll.ticket_id AND cta.brand_id = ll.brand_etl
    LEFT JOIN {{ source('paris', 'cs_ticket_source_api')}}         ctsa
        ON cta.ticket_id = ctsa.ticket_id
    LEFT JOIN {{ source('paris', 'cs_ticket_source_detail_api')}}  ctsda
        ON ctsa.ticket_source_detail_id = ctsda.id 
    LEFT JOIN {{ source('paris', 'crm_stage') }}            ecs
           ON ecs.id = ll.stage_id AND ecs.brand_etl = 3
    LEFT JOIN {{ source('paris', 'stag_sources') }}         ss1
           ON ss1.old_id = ll.source_id
    LEFT JOIN {{ source('paris', 'stag_sources') }}         ss2
           ON ss2.old_id = ss1.id_pr
    LEFT JOIN {{ source('paris', 'view_stag_products') }}   sp
           ON sp.product_id = ll.product_id AND sp.brand_etl = ll.brand_etl
    LEFT JOIN {{ source('paris', 'm_nhom_dv_adnet_paris') }} mndap
           ON mndap.default_code = sp.default_code AND sp.brand_etl = 3
    LEFT JOIN {{ source('paris', 'm_res_company') }}        mrc
           ON mrc.id = ll.company_id AND mrc.brand_etl = ll.brand_etl
)

-- Lead (Pass 9)
SELECT nguon, nhom_nguon, kenh,
    create_date::date   AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'Lead'::text        AS type_data
FROM base
WHERE create_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
  AND type = 'lead'
  AND stage_name IN ('Tiềm năng', 'Tham khảo', 'Đặt lịch')

-- Deal Caresoft nguồn google ads
UNION ALL
SELECT 
    sfdc.nguon, sfdc.nhom_nguon,    sfdc.kenh,
    sfdc.ngay,  sfdc.nhom_dv,       sfdc.chi_nhanh,
    sfdc.metric,sfdc.type_data
FROM {{ ref('stg_frmacpr_deal_cs')}} sfdc

UNION ALL
-- BK (Pass 10)
SELECT nguon, nhom_nguon, kenh,
    create_date::date   AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'BK'::text          AS type_data
FROM base
WHERE create_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
  AND type_crm_id = 2

UNION ALL

-- BKHL – Hẹn lịch (Pass 11)
SELECT nguon, nhom_nguon, kenh,
    booking_date::date  AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'BKHL'::text        AS type_data
FROM base
WHERE booking_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
  AND type_crm_id = 2

UNION ALL

-- DC – Đến cửa (Pass 12)
SELECT nguon, nhom_nguon, kenh,
    arrival_date::date  AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'DC'::text          AS type_data
FROM base
WHERE arrival_date::date >= '{{ var("start_date", "2025-08-01") }}'::date

UNION ALL

-- TC – Thành công (Pass 13)
SELECT nguon, nhom_nguon, kenh,
    arrival_date::date  AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'TC'::text          AS type_data
FROM base
WHERE arrival_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
  AND total_received > 0
