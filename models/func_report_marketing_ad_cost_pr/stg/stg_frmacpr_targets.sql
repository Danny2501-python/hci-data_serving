-- =============================================================================
-- stg_frmacpr_targets
-- PASS 7 & 8: Mục tiêu Lead và Chi phí từ bảng target daily Paris.
-- =============================================================================
SELECT
    'Mục tiêu'::text            AS nguon,
    'MD'::text                  AS nhom_nguon,
    'marketing'::text           AS kenh,
    date::date                  AS ngay,
    product_category            AS nhom_dv,
    'SCI'::text                 AS chi_nhanh,
    value::text                 AS metric,
    CASE
        WHEN type = 'Lead'      THEN 'target_lead'
        WHEN type = 'Chi phí'   THEN 'target_cost'
        ELSE type
    END                         AS type_data,
    null::text                  AS nguon_moi_v2,
    null::text                  AS nhom_nguon_moi_v2
FROM {{ ref('stg_frmacpr_target_daily_view') }}
WHERE type IN ('Lead', 'Chi phí')
