-- =============================================================================
-- stg_frmack_fb_insight
-- Now selecting directly from the source table stg_fb_insight_old.
-- Original logic backed up in analyses folder.
-- =============================================================================

SELECT * FROM {{ source('kangnam', 'stg_fb_insight_old') }}
WHERE page_id not in ('805410602664141','839493609256431','948044848396128')