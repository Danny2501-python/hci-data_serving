-- =============================================================================
-- stg_frmacpr_targets
-- PASS 7 & 8: Mục tiêu Lead và Chi phí từ bảng target daily Paris.
--
-- GRACEFUL DEGRADATION: nguồn view_ggs_paris_sm_target_daily được sync từ
-- Google Sheet bên ngoài, không do dbt quản lý. Nếu view chưa/không tồn tại,
-- model này trả về tập rỗng (đúng cấu trúc cột) thay vì làm sập cả
-- mart_report_marketing_ad_cost_pr (model table duy nhất, union tất cả
-- nguồn ephemeral trong 1 câu query). Xem LOGIC.md để biết chi tiết sự cố.
-- =============================================================================
{% set target_rel = adapter.get_relation(
    database=source('paris', 'view_ggs_paris_sm_target_daily').database,
    schema=source('paris', 'view_ggs_paris_sm_target_daily').schema,
    identifier=source('paris', 'view_ggs_paris_sm_target_daily').identifier
) %}

{% if target_rel is not none %}

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
    END                         AS type_data
FROM {{ source('paris', 'view_ggs_paris_sm_target_daily') }}
WHERE type IN ('Lead', 'Chi phí')

{% else %}

{{ log("⚠️ CẢNH BÁO: source paris.view_ggs_paris_sm_target_daily KHÔNG tồn tại — bỏ qua target_lead/target_cost trong mart_report_marketing_ad_cost_pr, build vẫn tiếp tục.", info=True) }}

SELECT
    NULL::text  AS nguon,
    NULL::text  AS nhom_nguon,
    NULL::text  AS kenh,
    NULL::date  AS ngay,
    NULL::text  AS nhom_dv,
    NULL::text  AS chi_nhanh,
    NULL::text  AS metric,
    NULL::text  AS type_data
WHERE false

{% endif %}
