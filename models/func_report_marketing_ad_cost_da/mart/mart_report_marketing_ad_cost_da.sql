{{
  config(
    materialized = 'table',
    alias        = 'report_marketing_ad_cost_da'
  )
}}

-- =============================================================================
-- mart_report_marketing_ad_cost_da — bảng báo cáo marketing ĐÔNG Á.
-- Cùng bộ cột với report_marketing_ad_cost_kn_v2 (Kangnam) + cột brand_etl = 2
-- ở cuối, để dùng chung workbook Tableau / gộp báo cáo tập đoàn.
--
-- Hiện chỉ có 2 stream không phải chi phí FB (giống Stream 2 / 3 bản Kangnam).
-- Stream 1 (chi phí Facebook) thêm khi kéo được chi phí FB Đông Á.
-- =============================================================================

-- ── Stream 2: ticket_id ≠ 0 ─────────────────────────────────────────────────
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
    m.page_name                                              AS page,
    m.page_id_from_camp                                      AS page_id,
    CASE WHEN ccm.continent IS NULL THEN UPPER(m.region) ELSE UPPER(ccm.continent) END AS region,
    m.tinh_noi,
    m.campaign,
    m.account_fb                                             AS account_fb,
    COALESCE(m.actor_code, 'KXĐ')::text                      AS actor,
    cns_mt.nhom_dv                                           AS nhom_dv_muc_tieu,
    COALESCE(m.nhom_dv_KH_quan_tam, 'KXĐ')::text             AS nhom_dv_KH_quan_tam,
    COALESCE(m.nhom_dv_KH_quan_tam_goc, 'KXĐ')::text         AS nhom_dv_KH_quan_tam_goc,
    m.nhom_dv_chinh_booking                                  AS nhom_dv_chinh_booking,
    m.nguon_moi_v2                                           AS nguon_moi_v2,
    m.nhom_nguon_moi_v2                                      AS nhom_nguon_moi_v2,
    2                                                        AS brand_etl
FROM {{ ref('int_frmacda_region') }} m
    LEFT JOIN {{ ref('ucbt_country_continent') }} ccm
        ON ccm.country = m.quoc_gia
    LEFT JOIN LATERAL (
        SELECT nhom_dv FROM {{ ref('campaign_name_split') }}
        WHERE UPPER(campain_name_split) = UPPER(m.nhom_dv_muc_tieu_code) LIMIT 1
    ) cns_mt ON TRUE
WHERE m.ticket_id <> 0

UNION ALL

-- ── Stream 3: ticket_id = 0 hoặc NULL ───────────────────────────────────────
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
    COALESCE(m.page_name, 'KXĐ')::text                       AS page,
    COALESCE(m.page_id_from_camp, 'KXĐ')::text               AS page_id,
    CASE WHEN ccm.continent IS NULL THEN UPPER(m.region) ELSE UPPER(ccm.continent) END AS region,
    m.tinh_noi,
    m.campaign,
    COALESCE(m.account_fb, 'KXĐ')::text                      AS account_fb,
    COALESCE(m.actor_code, 'KXĐ')::text                      AS actor,
    COALESCE(cns_mt.nhom_dv, 'KXĐ')::text                    AS nhom_dv_muc_tieu,
    COALESCE(m.nhom_dv_KH_quan_tam, 'KXĐ')::text             AS nhom_dv_KH_quan_tam,
    COALESCE(m.nhom_dv_KH_quan_tam_goc, 'KXĐ')::text         AS nhom_dv_KH_quan_tam_goc,
    COALESCE(m.nhom_dv_chinh_booking, 'KXĐ')::text           AS nhom_dv_chinh_booking,
    COALESCE(m.nguon_moi_v2, 'KXĐ')::text                    AS nguon_moi_v2,
    COALESCE(m.nhom_nguon_moi_v2, 'KXĐ')::text               AS nhom_nguon_moi_v2,
    2                                                        AS brand_etl
FROM {{ ref('int_frmacda_region') }} m
    LEFT JOIN {{ ref('ucbt_country_continent') }} ccm
        ON ccm.country = m.quoc_gia
    LEFT JOIN LATERAL (
        SELECT nhom_dv FROM {{ ref('campaign_name_split') }}
        WHERE UPPER(campain_name_split) = UPPER(m.nhom_dv_muc_tieu_code) LIMIT 1
    ) cns_mt ON TRUE
WHERE (m.ticket_id = 0 OR m.ticket_id IS NULL)
