-- =============================================================================
-- stg_frmacpr_inbox
-- PASS 14: Inbox Facebook Paris – số cuộc trò chuyện bắt đầu qua tin nhắn.
-- =============================================================================
WITH a AS (
    SELECT
        ipf.ngày                                                    AS date_raw,
        ipf."số cuộc trò chuyện bắt đầu qua tin nhắn"             AS ib,
        lpa.branch,
        ipf."tên quảng cáo"                                        AS campaign_raw,
        SPLIT_PART("tên quảng cáo", '_', 2)                       AS nhom_dv_raw,
        ipf."id page"                                              AS page_id_raw
    FROM {{ source('paris', 'inbox_paris_fb') }} ipf
    LEFT JOIN {{ source('paris', 'local_paris_adnet') }} lpa
           ON lpa.province = ipf.vùng
),

b AS (
    SELECT
        'FB'::text                                                  AS channel,
        date_raw::date                                              AS ngay,
        CASE nhom_dv_raw
            WHEN 'NRKT'      THEN 'Niềng răng khay trong'
            WHEN 'PTHM'      THEN 'PTHM'
            WHEN 'RANG SU'   THEN 'Răng sứ'
            WHEN 'IMPLANT'   THEN 'Implant'
            WHEN 'NIENG RANG' THEN 'Niềng răng mắc cài'
            ELSE nhom_dv_raw
        END                                                         AS nhom_dv,
        CASE UPPER(branch)
            WHEN 'HÀ NỘI'                        THEN 'HÀ NỘI'
            WHEN 'HỒ CHÍ MINH'                   THEN 'HỒ CHÍ MINH'
            WHEN 'NHA KHOA PARIS BẮC NINH'       THEN 'BẮC NINH'
            WHEN 'NHA KHOA PARIS HẢI PHÒNG'      THEN 'HẢI PHÒNG'
            WHEN 'NHA KHOA PARIS BUÔN MÊ THUỘT'  THEN 'BUÔN MÊ THUỘT'
            WHEN 'NHA KHOA PARIS ĐÀ NẴNG'        THEN 'ĐÀ NẴNG'
            WHEN 'NHA KHOA PARIS VINH'            THEN 'VINH'
            WHEN 'NHA KHOA PARIS THÁI NGUYÊN'    THEN 'THÁI NGUYÊN'
            WHEN 'NHA KHOA PARIS THANH HÓA'      THEN 'THANH HÓA'
            WHEN 'NHA KHOA PARIS BÌNH DƯƠNG'     THEN 'BÌNH DƯƠNG'
            WHEN 'NHA KHOA PARIS QUẢNG NINH'     THEN 'QUẢNG NINH'
            ELSE UPPER(branch)
        END                                                         AS chi_nhanh,
        ib,
        campaign_raw,
        page_id_raw
    FROM a
    WHERE ib IS NOT NULL
)

SELECT
    'MD - Facebook'::text       AS nguon,
    'MD'::text                  AS nhom_nguon,
    channel,
    ngay,
    nhom_dv,
    chi_nhanh,
    SUM(ib)::text               AS metric,
    'ib'::text                  AS type_data,
    -- Không có liên kết CRM, nhưng nhánh này là Inbox Facebook (nguon =
    -- 'MD - Facebook' ở trên) -> mặc định cứng theo catalog utm_source thật
    -- của Paris (id=731 'Facebook', category 'Online').
    'Facebook'::text            AS nguon_moi_v2,
    'Online'::text               AS nhom_nguon_moi_v2,
    COALESCE(campaign_raw, 'KXĐ')::text AS campaign,
    -- actor: campaign_name Inbox Paris đặt tên dạng {chi_nhanh}_{nhom_dv}_...
    -- (token 1 = mã chi nhánh: ALL/HCM/ĐN/HN/...), KHÔNG theo convention
    -- 9-token all_brand_mkt_camp -> guard dưới đây luôn ra NULL trên dữ liệu
    -- thật hiện tại (verify 2026-09-10). Vẫn viết dạng guard (không hard-code
    -- NULL) để tự động nhận actor nếu sau này đổi convention, giống page_code/
    -- nhom_dv ở model này.
    CASE
        WHEN SPLIT_PART(campaign_raw, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN SPLIT_PART(campaign_raw, '_', 8)
    END::text                   AS actor_code,
    -- nhom_dv_muc_tieu_code: viết dạng guard như actor_code (không hard-code
    -- NULL) nhưng thực tế cũng luôn ra NULL trên dữ liệu thật hiện tại, vì
    -- cùng lý do actor_code NULL — token 1 của campaign Inbox Paris là mã chi
    -- nhánh, không thuộc convention 9-token all_brand_mkt_camp.
    CASE
        WHEN SPLIT_PART(campaign_raw, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN SPLIT_PART(campaign_raw, '_', 5)
    END::text                   AS nhom_dv_muc_tieu_code,
    -- vk/ten_dv/local_k_raw/quoc_gia: không có liên kết CRM -> luôn NULL.
    NULL::text                  AS vk,
    NULL::text                  AS ten_dv,
    NULL::text                  AS local_k_raw,
    NULL::text                  AS quoc_gia,
    -- page_id_raw: thêm 2026-09-11 — inbox_paris_fb có sẵn cột "id page" (ID
    -- Trang Facebook thật của quảng cáo), tra tên qua dim_page ở mart — trực
    -- tiếp hơn cách func_report_marketing_ad_cost_kn làm cho Inbox (KN phải
    -- suy ra qua campaign_id -> dim_campaign -> dim_account vì
    -- m_inbox_kangnam không có sẵn page id).
    page_id_raw,
    -- account_id_raw: inbox_paris_fb không có cột account/ad_account ->
    -- luôn NULL (không suy ra được tài khoản FB như KN).
    NULL::text                  AS account_id_raw,
    NULL::text                  AS page_code_raw,
    NULL::text                  AS nhom_dv_kh_quan_tam,
    NULL::text                  AS nhom_dv_chinh_booking
FROM b
GROUP BY channel, ngay, nhom_dv, chi_nhanh, campaign_raw, page_id_raw
