-- =============================================================================
-- stg_frmacpr_target_daily_view
-- Materialize lại view public.view_ggs_paris_sm_target_daily bằng dbt (thay vì
-- phụ thuộc 1 view tạo tay ngoài DB, dễ bị mất) để tránh bị drop khỏi DB.
--
-- Bối cảnh: bảng gốc ggs_paris_sm_target là bảng ingest kiểu Google Sheet (có
-- snapshot_date/ingestion_timestamp/source_server, cùng dạng tiktok_raw_ad) —
-- nghi ngờ job sync định kỳ DROP + tạo lại bảng, kéo theo view phụ thuộc bị
-- drop (đã gặp thực tế 2026-08-09: dbt run báo lỗi "relation
-- view_ggs_paris_sm_target_daily does not exist"). Materialized = 'view' ở
-- đây khiến dbt tự CREATE OR REPLACE VIEW lại object này mỗi lần chạy
-- `dbt run --select tag:report_pr` — miễn bảng gốc ggs_paris_sm_target còn
-- tồn tại đúng schema thì view luôn được dựng lại, không phụ thuộc ai tạo tay.
--
-- alias giữ đúng tên cũ (view_ggs_paris_sm_target_daily) để báo cáo/dashboard
-- khác đang query trực tiếp object này không bị ảnh hưởng.
--
-- Logic giữ nguyên y hệt định nghĩa gốc lấy từ pg_get_viewdef() (2026-08-09).
-- Script chạy tay/backup tương đương:
-- analyses/func_report_marketing_ad_cost_pr/create_view_ggs_paris_sm_target_daily.sql
-- =============================================================================
{{
  config(
    materialized = 'view',
    alias        = 'view_ggs_paris_sm_target_daily'
  )
}}

WITH date_range AS (
    SELECT
        (generate_series(
            t.date_from::timestamp with time zone,
            t.date_to::timestamp with time zone,
            '1 day'::interval
        ))::date                                   AS date,
        t.type,
        t.product_category,
        t.value,
        (t.date_to - t.date_from) + 1               AS total_days
    FROM {{ source('paris', 'ggs_paris_sm_target') }} t
)
SELECT
    date_range.date,
    date_range.type,
    date_range.product_category,
    CASE
        WHEN date_range.type = 'Lead'::text     THEN round(date_range.value::numeric / date_range.total_days::numeric, 2)
        WHEN date_range.type = 'Chi phí'::text  THEN round(date_range.value::numeric / date_range.total_days::numeric, 2)
        ELSE NULL::numeric
    END                                              AS value
FROM date_range
ORDER BY date_range.date, date_range.type, date_range.product_category
