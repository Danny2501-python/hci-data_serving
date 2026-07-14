-- =============================================================================
-- stg_frmack_fb_insight
-- Now selecting directly from the source table stg_fb_insight_old.
-- Original logic backed up in analyses folder.
-- =============================================================================
-- cắt dữ liệu cũ
SELECT *,null as country,null as actor_code,null as nhom_dv_muc_tieu_code FROM {{ source('kangnam', 'stg_fb_insight_old_zero') }}
WHERE page_id not in ('805410602664141','839493609256431','948044848396128')