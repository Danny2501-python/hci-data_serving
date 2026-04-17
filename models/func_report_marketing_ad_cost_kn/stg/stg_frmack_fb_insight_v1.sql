-- =============================================================================
-- stg_frmack_fb_insight
-- Now selecting directly from the source table stg_fb_insight_old.
-- Original logic backed up in analyses folder.
-- =============================================================================

SELECT * FROM {{ source('kangnam', 'stg_fb_insight_old') }}
