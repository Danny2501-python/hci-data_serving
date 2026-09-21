{{
  config(
    materialized = 'table',
    alias        = 'report_marketing_ad_cost_kn_v2'
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
    CASE WHEN mcp.page_name = 'N/A' THEN 'KXĐ' ELSE mcp.page_name END                                          AS page,
    f.page_id,
    CASE
        WHEN f.vk = 'VIỆT KIỀU'                         THEN UPPER(f.local_k)
        WHEN f.vk = 'QUỐC TẾ'                           THEN UPPER(f.local_k)
        WHEN tn.tinh_noi = 'Bà Rịa - Vũng Tàu'          THEN 'HỒ CHÍ MINH VÀ LÂN CẬN'
        WHEN tn.tinh_noi ILIKE '%Lào Cai%'              THEN 'MIỀN BẮC MỞ RỘNG'
        WHEN tn.tinh_noi ILIKE '%Yên Bái%'              THEN 'MIỀN BẮC MỞ RỘNG'
        WHEN tn.tinh_noi ILIKE '%Huế%'                  THEN 'ĐÀ NẴNG LÂN CẬN'
        WHEN tn.tinh_noi = 'KXĐ' or grm.region is null  THEN 'KXĐ'
        ELSE UPPER(grm.region)
    END                                                      AS region,
    tn.tinh_noi,
    f.camp_name                                              AS campaign,
    f.account_fb,
    COALESCE(f.actor_code,'KXĐ')::text                       AS actor,
    cns_mt.nhom_dv                                           AS nhom_dv_muc_tieu,
    null::text                                                AS nhom_dv_KH_quan_tam,
    null::text                                                AS nhom_dv_KH_quan_tam_goc,
    null::text                                                AS nhom_dv_chinh_booking,
    -- Không có liên kết CRM, nhưng Stream 1 chỉ là chi phí quảng cáo Facebook
    -- (int_frmack_fb_cost) -> mặc định cứng theo catalog utm_source thật của
    -- Kangnam (id=751 'Facebook', category 'Online') thay vì NULL.
    'Facebook'::text                                          AS nguon_moi_v2,
    'Online'::text                                            AS nhom_nguon_moi_v2
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
LEFT JOIN {{ ref('dim_page') }} mcp ON mcp.page_id::text = f.page_id::text
LEFT JOIN {{ source('kangnam','ucbt_country_continent') }} ccm
    ON ccm.country = f.quoc_gia
LEFT JOIN LATERAL (
    SELECT nhom_dv FROM {{ ref('campaign_name_split') }}
    WHERE UPPER(campain_name_split) = UPPER(f.nhom_dv_muc_tieu_code) LIMIT 1
) cns_mt ON TRUE

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
    m.page_name                                         AS page,
    m.page_id_from_camp                                         AS page_id,
    CASE WHEN ccm.continent IS NULL THEN UPPER(m.region) ELSE UPPER(ccm.continent) END AS region,
    m.tinh_noi,
    m.campaign,
    m.account_fb                                             AS account_fb,
    COALESCE(m.actor_code,'KXĐ')::text                       AS actor,
    cns_mt.nhom_dv                                           AS nhom_dv_muc_tieu,
    COALESCE(m.nhom_dv_KH_quan_tam,'KXĐ')::text                AS nhom_dv_KH_quan_tam,
    COALESCE(m.nhom_dv_KH_quan_tam_goc,'KXĐ')::text            AS nhom_dv_KH_quan_tam_goc,
    m.nhom_dv_chinh_booking                                  AS nhom_dv_chinh_booking,
    m.nguon_moi_v2                                           AS nguon_moi_v2,
    m.nhom_nguon_moi_v2                                      AS nhom_nguon_moi_v2
FROM {{ ref('int_frmack_region') }} m
    LEFT JOIN {{ source('kangnam','ucbt_country_continent') }} ccm
        ON ccm.country = m.quoc_gia
    LEFT JOIN LATERAL (
        SELECT nhom_dv FROM {{ ref('campaign_name_split') }}
        WHERE UPPER(campain_name_split) = UPPER(m.nhom_dv_muc_tieu_code) LIMIT 1
    ) cns_mt ON TRUE
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
    CASE WHEN ccm.continent IS NULL THEN UPPER(m.region) ELSE UPPER(ccm.continent) END AS region,
    m.tinh_noi,
    m.campaign,
    COALESCE(m.account_fb,'KXĐ')::text                       AS account_fb,
    COALESCE(m.actor_code,'KXĐ')::text                       AS actor,
    COALESCE(cns_mt.nhom_dv,'KXĐ')::text                      AS nhom_dv_muc_tieu,
    COALESCE(m.nhom_dv_KH_quan_tam,'KXĐ')::text                AS nhom_dv_KH_quan_tam,
    COALESCE(m.nhom_dv_KH_quan_tam_goc,'KXĐ')::text            AS nhom_dv_KH_quan_tam_goc,
    COALESCE(m.nhom_dv_chinh_booking,'KXĐ')::text             AS nhom_dv_chinh_booking,
    COALESCE(m.nguon_moi_v2,'KXĐ')::text                      AS nguon_moi_v2,
    COALESCE(m.nhom_nguon_moi_v2,'KXĐ')::text                 AS nhom_nguon_moi_v2
FROM {{ ref('int_frmack_region') }} m
    LEFT JOIN {{ source('kangnam','ucbt_country_continent') }} ccm
        ON ccm.country = m.quoc_gia
    LEFT JOIN LATERAL (
        SELECT nhom_dv FROM {{ ref('campaign_name_split') }}
        WHERE UPPER(campain_name_split) = UPPER(m.nhom_dv_muc_tieu_code) LIMIT 1
    ) cns_mt ON TRUE
WHERE (m.ticket_id = 0 OR m.ticket_id IS NULL)
