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
        tra."tên chiến dịch"                                        AS campaign_raw,
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
    'Online'::text                                                  AS nhom_nguon_moi_v2,
    -- campaign/actor: toàn bộ campaign_name hiện có (verify 2026-09-10) đều
    -- token 1 = 'prd' -> nằm trong whitelist all_brand_mkt_camp, actor tách
    -- được ở token vị trí 8 (giống pattern "trangnn" ghi trong LOGIC.md).
    COALESCE(campaign_raw, 'KXĐ')::text                             AS campaign,
    CASE
        WHEN SPLIT_PART(campaign_raw, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN SPLIT_PART(campaign_raw, '_', 8)
    END::text                                                       AS actor_code,
    -- nhom_dv_muc_tieu_code: token vị trí 5, cùng guard với actor_code.
    CASE
        WHEN SPLIT_PART(campaign_raw, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN SPLIT_PART(campaign_raw, '_', 5)
    END::text                                                       AS nhom_dv_muc_tieu_code,
    -- vk/ten_dv/local_k_raw/quoc_gia/page_id_raw/account_id_raw: thêm
    -- 2026-09-11 — TikTok không có liên kết CRM lẫn khái niệm FB
    -- Page/Account -> luôn NULL.
    NULL::text                                                      AS vk,
    NULL::text                                                      AS ten_dv,
    NULL::text                                                      AS local_k_raw,
    NULL::text                                                      AS quoc_gia,
    NULL::text                                                      AS page_id_raw,
    NULL::text                                                      AS account_id_raw,
    NULL::text                                                      AS page_code_raw,
    NULL::text                                                      AS nhom_dv_kh_quan_tam,
    NULL::text                                                      AS nhom_dv_chinh_booking
FROM a
