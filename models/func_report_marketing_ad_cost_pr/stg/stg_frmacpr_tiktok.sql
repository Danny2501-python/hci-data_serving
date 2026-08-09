-- =============================================================================
-- stg_frmacpr_tiktok
-- PASS x: Chi phí TikTok Ads cho Paris.
-- Nguồn: tiktok_raw_ad (đồng bộ thủ công từ Google Sheet, không có cột brand ->
-- toàn bộ bảng được coi là dữ liệu Paris, xem LOGIC.md).
-- =============================================================================
WITH a AS (
    SELECT
        tra."date created"::date                                   AS ngay_chi_phi,
        tra."chi phí"::text                                        AS chi_phi,
        -- campaign_name dạng: prd_prtk002_{}_{}_<nhom_dv>_ib_mofub_trangnn_<variant>_<datecode>
        SPLIT_PART(tra."tên chiến dịch", '_', 5)                    AS nhom_dv_raw
    FROM {{ source('paris', 'tiktok_raw_ad') }} tra
    WHERE tra."date created"::date >= '{{ var("start_date", "2025-08-01") }}'::date
)

SELECT
    'MD - Tiktok'::text                                             AS nguon,
    'MD'::text                                                      AS nhom_nguon,
    'TikTok'::text                                                  AS channel,
    ngay_chi_phi                                                    AS ngay,
    CASE
        WHEN UPPER(nhom_dv_raw) LIKE '%NIENG%'                      THEN 'Niềng răng'
        WHEN UPPER(nhom_dv_raw) = 'IMPLANT'                         THEN 'Implant'
        WHEN UPPER(nhom_dv_raw) LIKE '%RANGSU%'
          OR UPPER(nhom_dv_raw) LIKE '%RANG SU%'                    THEN 'Răng sứ'
        ELSE UPPER(nhom_dv_raw)
    END                                                              AS nhom_dv,
    -- Vị trí chi nhánh trong campaign_name (phần "{}") chưa được điền ở dữ liệu
    -- hiện có -> tạm gán KXĐ, xem LOGIC.md để cập nhật khi có quy ước thật.
    'KXĐ'::text                                                     AS chi_nhanh,
    chi_phi                                                         AS metric,
    'tiktok'::text                                                  AS type_data,
    -- Không có liên kết CRM, nhưng nhánh này là chi phí quảng cáo TikTok
    -- -> mặc định cứng theo catalog utm_source thật của Paris (id=733
    -- 'Tiktok', category 'Online').
    'Tiktok'::text                                                  AS nguon_moi_v2,
    'Online'::text                                                  AS nhom_nguon_moi_v2
FROM a
