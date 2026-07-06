{{
  config(
    materialized = 'table',
    alias        = 'report_marketing_ad_cost_kn_v3'
  )
}}
-- =============================================================================
-- frmack_report_marketing_kn  (Pass 15 — Final output)
-- 3 streams exactly as in original:
--   Stream 1 (FB cost)     : t_fb_cost → map page by page_id
--   Stream 2 (non-FB, id≠0): t_mkt_cp  → map page by ticket_id (LEFT JOIN)
--   Stream 3 (non-FB, id=0): t_mkt_cp  → page = KXĐ
-- =============================================================================

-- ── Stream 1: Facebook cost ─────────────────────────────────────────────────
SELECT
    f.vk,
    f.ten_dv,
    f.nguon                                                  AS "Nguon",
    f.nhom_nguon                                             AS "Nhom_nguon",
    f.kenh,
    f.ngay                                                   AS "date",
    f.nhom_dv_sys                                            AS nhom_dv,
    f.chi_nhanh,
    f.local_k,
    f.quoc_gia,
    ccm.continent                                            AS chau_luc,
    f.metric                                                 AS "Metric",
    f.type_data,
    mcp.service_name                                         AS page,
    f.page_id,
    CASE
        WHEN f.vk = 'VIỆT KIỀU'                     THEN f.local_k
        WHEN f.vk = 'QUỐC TẾ'                       THEN f.local_k
        WHEN tn.tinh_noi = 'Bà Rịa - Vũng Tàu'      THEN 'Hồ Chí Minh và lân cận'
        WHEN tn.tinh_noi ILIKE '%Lào Cai%'          THEN 'Miền Bắc mở rộng'
        WHEN tn.tinh_noi ILIKE '%Yên Bái%'          THEN 'Miền Bắc mở rộng'
        WHEN tn.tinh_noi ILIKE '%Huế%'              THEN 'Đà nẵng lân cận'
        WHEN tn.tinh_noi = 'KXĐ'                    THEN 'KXĐ'
        ELSE grm.region
    END                                                      AS region,
    tn.tinh_noi,
    f.camp_name                                              AS campaign,
    f.account_fb,
    f.actor
FROM {{ ref('int_frmack_fb_cost') }} f
-- Compute tinh_noi inline (same re_map formula as Pass 12)
LEFT JOIN LATERAL (
    SELECT
        CASE WHEN f.local_k ~~* '%thành phố%'
                 THEN regexp_replace(f.local_k, '^Thành phố\s*', '')
             WHEN f.local_k ~~* '%Tỉnh%'
                 THEN regexp_replace(f.local_k, '^Tỉnh\s*', '')
             WHEN f.local_k ~~ '%Bà Rịa%'
                 THEN 'Bà Rịa – Vũng Tàu'
             WHEN f.local_k ~~* '%VIỆT KIỀU%'
                 THEN 'VIỆT KIỀU'
             ELSE f.local_k
        END AS tinh_noi
) tn ON TRUE
LEFT JOIN {{ source('kangnam', 'ggs_region_map') }} grm
       ON grm.location = tn.tinh_noi
-- Map page by page_id (dedup by created_at DESC like original Pass 15)
LEFT JOIN (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY page_id ORDER BY created_at DESC) AS rn
    FROM {{ ref('stg_frmack_cs_services') }}
) mcp ON mcp.page_id::text = f.page_id::text AND mcp.rn = 1
LEFT JOIN {{ source('kangnam','ucbt_country_continent') }} ccm
    ON ccm.country = f.quoc_gia

UNION ALL

-- ── Stream 2: non-FB, ticket_id ≠ 0 → map page via ticket → service ────────
SELECT
    m.vk,
    m.ten_dv,
    m.nguon                                                  AS "Nguon",
    m.nhom_nguon                                             AS "Nhom_nguon",
    m.kenh,
    m.ngay                                                   AS "date",
    m.nhom_dv,
    m.chi_nhanh,
    m.local_k,
    m.quoc_gia,
    ccm.continent                                            AS chau_luc,
    m.metric                                                 AS "Metric",
    m.type_data,
    mms.service_name                                         AS page,
    mms.page_id,
    CASE WHEN ccm.continent IS NULL THEN m.region ELSE ccm.continent END AS region,
    m.tinh_noi,
    m.campaign,
    m.account_fb                                               AS account_fb,
    m.camp_actor                                               AS actor
FROM {{ ref('int_frmack_region') }} m
    LEFT JOIN (
        SELECT * FROM {{ ref('stg_frmack_cs_tickets') }} WHERE rnk = 1
    ) tcp ON tcp.ticket_id = m.ticket_id
    LEFT JOIN {{ ref('stg_frmack_cs_services') }} mms
        ON mms.service_id = tcp.service_id
    LEFT JOIN {{ source('kangnam','ucbt_country_continent') }} ccm
        ON ccm.country = m.quoc_gia
WHERE m.ticket_id <> 0

UNION ALL

-- ── Stream 3: non-FB, ticket_id = 0 or NULL → page = KXĐ ───────────────────
SELECT
    m.vk,
    m.ten_dv,
    m.nguon                                                  AS "Nguon",
    m.nhom_nguon                                             AS "Nhom_nguon",
    m.kenh,
    m.ngay                                                   AS "date",
    m.nhom_dv,
    m.chi_nhanh,
    m.local_k,
    m.quoc_gia,
    ccm.continent                                            AS chau_luc,
    m.metric                                                 AS "Metric",
    m.type_data,
    COALESCE(m.page_name,'KXĐ')::text                        AS page,
    COALESCE(m.page_id_from_camp,'KXĐ')::text                  AS page_id,
    CASE WHEN ccm.continent IS NULL THEN m.region ELSE ccm.continent END AS region,
    m.tinh_noi,
    m.campaign,
    m.account_fb                                               AS account_fb,
    m.camp_actor                                               AS actor
FROM {{ ref('int_frmack_region') }} m
    LEFT JOIN {{ source('kangnam','ucbt_country_continent') }} ccm
        ON ccm.country = m.quoc_gia
WHERE (m.ticket_id = 0 OR m.ticket_id IS NULL)
