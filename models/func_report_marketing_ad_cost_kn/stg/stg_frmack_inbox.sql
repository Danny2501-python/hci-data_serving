-- =============================================================================
-- stg_frmack_inbox  (Pass 9)
-- Inbox Facebook with DISTINCT (matching original col list incl. id chiến dịch)
-- cn = split_part(1) for vk/chi_nhanh checks.
-- Regular LEFT JOIN campaign_name_split (not LATERAL LIMIT 1).
-- =============================================================================

WITH a AS (
    SELECT DISTINCT
        mik."tên chiến dịch",
        mik."vùng",
        mik."id chiến dịch"::text                                    AS id_chien_dich,
        mik."ngày"::date                                             AS ngay,
        mik."người liên hệ qua nhắn tin mới",
        lka.tinh,
        lka."chi nhánh"                                              AS chi_nhanh_qc,
        lka.ngay_hh,
        CASE
            WHEN split_part(mik."tên chiến dịch", '_', 1) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 2)
        END                                                          AS page_code,
        CASE
            WHEN split_part(mik."tên chiến dịch", '_', 1) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 8)
        END                                                          AS actor_code,
        CASE
            WHEN split_part(mik."tên chiến dịch", '_', 1) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 5)
        END                                                          AS nhom_dv_muc_tieu_code,
        CASE
            WHEN split_part(mik."tên chiến dịch", '_', 1) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 3)
            ELSE TRIM(split_part(mik."tên chiến dịch", '_', 1))
        END                                                          AS cn,
        CASE 
            WHEN split_part(mik."tên chiến dịch", '_', 1) IN {{var('all_brand_mkt_camp')}} THEN split_part(mik."tên chiến dịch", '_', 5)
            ELSE UPPER(TRIM(split_part(mik."tên chiến dịch", '_', 2)))
        END                                                          AS nhom_dv_qc,
        mik."vùng"                                                   AS local
    FROM {{ source('kangnam', 'm_inbox_kangnam') }} mik
    LEFT JOIN LATERAL (
        SELECT lka1.tinh, lka1."chi nhánh", lka1.ngay_hh
        FROM {{ source('kangnam', 'location_kangnam_adnet') }} lka1
        WHERE lka1.tinh = mik."vùng"
          AND mik."ngày"::date >= lka1.ngay_hh
        ORDER BY lka1.ngay_hh DESC LIMIT 1
    ) lka ON TRUE
    WHERE mik."ngày"::date >= '{{ var("start_date", "2025-08-01") }}'::date
),
i AS (
    SELECT
        CASE WHEN a.cn ILIKE '%Hai Ngoai%' or a.cn = 'vki' THEN 'VIỆT KIỀU'
             WHEN a.cn ILIKE '%QUOC TE%' or a.cn = 'qte' THEN 'QUỐC TẾ'
             WHEN a.cn = 'exp' THEN 'exp'
             ELSE 'no'
        END                                                          AS vk,
        a.local,
        a."tên chiến dịch"                                           AS ten_ad,
        a.ngay,
        cns.nhom_dv                                                  AS nhom_dv_sys,
        CASE WHEN a.chi_nhanh_qc IS NULL AND a.cn NOT ILIKE '%QUOC TE%' THEN 'VIỆT KIỀU'
             WHEN a.chi_nhanh_qc IS NULL AND a.cn     ILIKE '%QUOC TE%' THEN 'QUỐC TẾ'
             ELSE a.chi_nhanh_qc
        END                                                          AS chi_nhanh_inter,
        a."người liên hệ qua nhắn tin mới"::text                    AS metric,
        upc.page_name  ,upc.page_id, a.actor_code, a.nhom_dv_muc_tieu_code, da.account_name AS account_fb
    FROM a
    -- Regular LEFT JOIN (not LATERAL) — matching original Pass 9
    LEFT JOIN {{ ref('campaign_name_split') }} cns
           ON UPPER(cns.campain_name_split) = UPPER(a.nhom_dv_qc)
    LEFT JOIN {{ ref('ucbt_page_config') }} upc
           ON upc.page_code = a.page_code
    -- Campaign không đi qua Caresoft ticket (Inbox không có ad_id_value); dùng
    -- "id chiến dịch" có sẵn trong m_inbox_kangnam để lấy account_fb (FB Ad Account name)
    LEFT JOIN {{ ref('dim_campaign') }} dc
           ON dc.campaign_id::text = a.id_chien_dich
    LEFT JOIN {{ ref('dim_account') }} da
           ON da.account_id::text = dc.ad_account_id::text
    WHERE a."người liên hệ qua nhắn tin mới" IS NOT NULL
)
SELECT
    i.vk,
    'DV'::text   AS ten_dv,
    'IB'::text   AS nguon,
    'IB'::text   AS nhom_nguon,
    'FB'::text   AS kenh,
    i.ngay,
    i.nhom_dv_sys AS nhom_dv,
    CASE i.chi_nhanh_inter
        WHEN 'HÀ NỘI' THEN 'BỆNH VIỆN KANGNAM HÀ NỘI'
        ELSE CASE UPPER(i.chi_nhanh_inter)
            WHEN 'HCM'            THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
            WHEN 'VK'             THEN 'VIỆT KIỀU'
            WHEN 'VIỆT KIỀU'     THEN 'VIỆT KIỀU'
            WHEN 'BẮC NINH'      THEN 'VIỆN THẨM MỸ KANGNAM BẮC NINH'
            WHEN 'HẢI PHÒNG'     THEN 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'
            WHEN 'BUÔN MÊ THUỘT' THEN 'VIỆN THẨM MỸ KANGNAM BUÔN MA THUỘT'
            WHEN 'ĐÀ NẴNG'       THEN 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'
            WHEN 'CẦN THƠ'       THEN 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'
            WHEN 'NGHỆ AN'       THEN 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'
            WHEN 'THÁI NGUYÊN'   THEN 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN'
            WHEN 'THANH HÓA'     THEN 'VIỆN THẨM MỸ KANGNAM THANH HÓA'
            WHEN 'BÌNH DƯƠNG'    THEN 'VIỆN THẨM MỸ KANGNAM BÌNH DƯƠNG'
            ELSE UPPER(i.chi_nhanh_inter)
        END
    END           AS chi_nhanh,
    CASE i.local
        WHEN 'Ho Chi Minh City' THEN 'SÀI GÒN'
        WHEN 'Hanoi'            THEN 'Hà Nội'
        WHEN 'Da Nang'          THEN 'Thành phố Đà Nẵng'
        WHEN 'Cần Thơ'          THEN 'Thành phố Cần Thơ'
        WHEN 'Haiphong'         THEN 'Thành phố Hải Phòng'
        ELSE CASE
            WHEN i.chi_nhanh_inter = 'VIỆT KIỀU' THEN 'VIỆT KIỀU'
            WHEN i.chi_nhanh_inter = 'QUỐC TẾ'  THEN 'QUỐC TẾ'
            ELSE 'Tỉnh ' || regexp_replace(i.local, '\s*Province$', '')
        END
    END           AS local_k,
    CASE WHEN i.chi_nhanh_inter = 'VIỆT KIỀU' THEN 'VIỆT KIỀU'
         WHEN i.chi_nhanh_inter = 'QUỐC TẾ'  THEN 'QUỐC TẾ'
         ELSE 'Việt Nam'
    END           AS quoc_gia,
    i.metric,
    'inbox'::text AS type_data,
    0             AS ticket_id,
    i.page_name,i.page_id,i.ten_ad as campaign,i.actor_code,i.account_fb,i.nhom_dv_muc_tieu_code
FROM i
