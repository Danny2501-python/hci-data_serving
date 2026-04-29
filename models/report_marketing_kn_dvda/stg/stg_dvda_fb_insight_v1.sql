-- stg_dvda_fb_insight_v1: Lấy dữ liệu legacy đã được đóng gói từ bảng vật lý
-- Logic gốc được lưu tại: analyses/report_marketing_kn_dvda/stg_dvda_fb_insight_v1_backup.sql

SELECT * FROM {{ source('dvda', 'stg_dvda_fb_insight_v1') }}
