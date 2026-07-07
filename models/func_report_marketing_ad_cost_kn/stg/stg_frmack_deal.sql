-- =============================================================================
-- stg_frmack_deal
-- Deal từ Caresoft tickets có FB ad attribution, enriched giống FB cost.
-- Điều kiện: sdt NOT NULL, ad_id NOT NULL, ngay_tao >= start_date.
-- Lưu ý: local_k = NULL vì ticket không có region (vung) của ad impression.
-- =============================================================================

-- Bước 1: join dim tables, parse campaign name
WITH base AS (
    SELECT
        t.ticket_id,
        t.service_id,
        t.ngay_tao,
        t.sdt,
        t.ad_id,
        dc.campaign_name,
        da.account_name                                              AS account_fb,
        -- Parse campaign name (naming mới: segments >= 9, segment 1 in all_brand_mkt_camp)
        CASE
            WHEN cardinality(string_to_array(dc.campaign_name, '_')) >= 9
                 AND split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN split_part(dc.campaign_name, '_', 3)
        END                                                          AS cn,
        CASE
            WHEN cardinality(string_to_array(dc.campaign_name, '_')) >= 9
                 AND split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN split_part(dc.campaign_name, '_', 5)
        END                                                          AS nhom_dv_raw,
        CASE
            WHEN cardinality(string_to_array(dc.campaign_name, '_')) >= 9
                 AND split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN split_part(dc.campaign_name, '_', 8)
            ELSE NULL
        END                                                          AS actor
    FROM {{ ref('stg_frmack_cs_tickets') }} t
    LEFT JOIN {{ source('kangnam', 'dim_camp_adset_ad') }} dca
           ON dca.ad_id = t.ad_id
    LEFT JOIN {{ source('kangnam', 'dim_campaign') }}      dc
           ON dc.campaign_id = dca.ad_campaign_id
    LEFT JOIN {{ source('kangnam', 'dim_account') }}       da
           ON da.account_id = dca.account_id
    WHERE t.sdt   IS NOT NULL
      AND t.ad_id IS NOT NULL
      AND t.ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
),

-- Bước 2: derive vk, chi_nhanh_inter, nhom_dv_sys (giống int_frmack_fb_cost)
enriched AS (
    SELECT
        b.*,
        CASE
            WHEN b.cn ILIKE '%Hai Ngoai%' OR b.cn = 'vki'  THEN 'VIỆT KIỀU'
            WHEN b.cn ILIKE '%QUOC TE%'   OR b.cn = 'qte'  THEN 'QUỐC TẾ'
            WHEN b.cn IN ('exp', 'expat')                    THEN 'exp'
            ELSE 'no'
        END                                                          AS vk,
        -- chi_nhanh_no_camp không có (không có region từ ticket) → fallback theo cn
        CASE
            WHEN b.cn ILIKE '%QUOC TE%'    OR b.cn = 'qte'  THEN 'QUỐC TẾ'
            WHEN b.cn ILIKE '%Hai Ngoai%'  OR b.cn = 'vki'  THEN 'VIỆT KIỀU'
            ELSE NULL
        END                                                          AS chi_nhanh_inter,
        COALESCE(cns.nhom_dv, b.nhom_dv_raw)                        AS nhom_dv_sys
    FROM base b
    LEFT JOIN LATERAL (
        SELECT nhom_dv
        FROM {{ source('kangnam', 'campaign_name_split') }}
        WHERE UPPER(campain_name_split) = UPPER(b.nhom_dv_raw)
        LIMIT 1
    ) cns ON TRUE
)

-- Bước 3: output với đầy đủ columns cho int_frmack_union
SELECT
    e.vk,
    'DV'::text                                                       AS ten_dv,
    'MD - Facebook'::text                                            AS nguon,
    'Facebook'::text                                                 AS nhom_nguon,
    'FB'::text                                                       AS kenh,
    e.ngay_tao                                                       AS ngay,
    e.nhom_dv_sys                                                    AS nhom_dv,
    CASE UPPER(e.chi_nhanh_inter)
        WHEN 'HCM'            THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
        WHEN 'HỒ CHÍ MINH'   THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
        WHEN 'HÀ NỘI'         THEN 'BỆNH VIỆN KANGNAM HÀ NỘI'
        WHEN 'BẮC NINH'       THEN 'VIỆN THẨM MỸ KANGNAM BẮC NINH'
        WHEN 'HẢI PHÒNG'      THEN 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'
        WHEN 'BUÔN MÊ THUỘT'  THEN 'VIỆN THẨM MỸ KANGNAM BUÔN MA THUỘT'
        WHEN 'ĐÀ NẴNG'        THEN 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'
        WHEN 'CẦN THƠ'        THEN 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'
        WHEN 'NGHỆ AN'        THEN 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'
        WHEN 'THÁI NGUYÊN'    THEN 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN'
        WHEN 'THANH HÓA'      THEN 'VIỆN THẨM MỸ KANGNAM THANH HÓA'
        WHEN 'BÌNH DƯƠNG'     THEN 'VIỆN THẨM MỸ KANGNAM BÌNH DƯƠNG'
        WHEN 'VINH'           THEN 'VIỆN THẨM MỸ KANGNAM VINH'
        WHEN NULL then 'KXĐ'
        ELSE e.chi_nhanh_inter
    END                                                              AS chi_nhanh,
    'KXĐ'::text                                                       AS local_k,
    CASE
        WHEN e.chi_nhanh_inter = 'VIỆT KIỀU' THEN 'VIỆT KIỀU'
        WHEN e.chi_nhanh_inter = 'QUỐC TẾ'  THEN 'QUỐC TẾ'
        ELSE 'Việt Nam'
    END                                                              AS quoc_gia,
    e.sdt::text                                                      AS metric,
    'Deal'::text                                                     AS type_data,
    e.ticket_id,
    e.campaign_name,
    svc.service_name                                                 AS page_name,
    svc.page_id                                                      AS page_id_from_camp,
    e.actor                                                          AS camp_actor,
    e.account_fb
FROM enriched e
LEFT JOIN (
    SELECT service_id, service_name, page_id,
           ROW_NUMBER() OVER (PARTITION BY service_id ORDER BY created_at DESC) AS rn
    FROM {{ ref('stg_frmack_cs_services') }}
) svc ON svc.service_id = e.service_id AND svc.rn = 1
