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
    null::text                  AS nhom_nguon_moi_v2,
    -- Giữ NULL — "Mục tiêu" không phải traffic thật, không gắn với 1
    -- campaign/actor cụ thể nào (cùng lý do với nguon_moi_v2 ở trên).
    null::text                  AS campaign,
    null::text                  AS actor_code,
    null::text                  AS nhom_dv_muc_tieu_code,
    null::text                  AS vk,
    null::text                  AS ten_dv,
    null::text                  AS local_k_raw,
    null::text                  AS quoc_gia,
    null::text                  AS page_id_raw,
    null::text                  AS account_id_raw,
    null::text                  AS page_code_raw,
    null::text                  AS nhom_dv_kh_quan_tam,
    null::text                  AS nhom_dv_chinh_booking
FROM {{ ref('stg_frmacpr_target_daily_view') }}
WHERE type IN ('Lead', 'Chi phí')
