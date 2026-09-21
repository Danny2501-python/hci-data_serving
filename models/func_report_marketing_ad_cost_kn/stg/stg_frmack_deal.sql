-- =============================================================================
-- stg_frmack_deal
-- "DealCS" block: Caresoft tickets with FB ad attribution (ad_id parsed from
-- cs_ticket_api.ad_id_value via stg_frmack_cs_tickets), enriched the same way
-- as the CRM-based branches in int_frmack_union (campaign/page/actor/account_fb).
-- metric = phone number (sdt), parsed from cs_ticket_api.requester.phone_no.
-- Điều kiện: sdt NOT NULL, ad_id NOT NULL, ngay_tao >= start_date.
-- Lưu ý: local_k = 'KXĐ' vì ticket không có region (vùng) của ad impression.
-- page_name lấy qua page_code + ucbt_page_config (KHÔNG dùng cs_services —
-- xem README mục 5, cách đó đã bị revert vì gây page NULL sai).
-- =============================================================================

WITH base AS (
    SELECT
        t.ticket_id,
        t.ngay_tao,
        t.sdt,
        t.ad_id,
        dc.campaign_name,
        da.account_name                                              AS account_fb,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN split_part(dc.campaign_name, '_', 2)
        END                                                          AS page_code,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN split_part(dc.campaign_name, '_', 3)
        END                                                          AS cn,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN split_part(dc.campaign_name, '_', 5)
        END                                                          AS nhom_dv_raw,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN split_part(dc.campaign_name, '_', 8)
        END                                                          AS actor_code
    FROM {{ ref('stg_frmack_cs_tickets') }} t
    LEFT JOIN {{ ref('dim_camp_adset_ad') }} dcaa
           ON dcaa.ad_id::text = t.ad_id::text
    LEFT JOIN {{ ref('dim_campaign') }} dc
           ON dc.campaign_id::text = dcaa.ad_campaign_id::text
    LEFT JOIN {{ ref('dim_account') }} da
           ON da.account_id::text = dcaa.account_id::text
    WHERE t.rnk = 1
      AND t.sdt   IS NOT NULL
      AND t.ad_id IS NOT NULL
      AND t.ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
),
enriched AS (
    SELECT
        b.*,
        CASE
            WHEN b.cn ILIKE '%Hai Ngoai%' OR b.cn = 'vki'  THEN 'VIỆT KIỀU'
            WHEN b.cn ILIKE '%QUOC TE%'   OR b.cn = 'qte'  THEN 'QUỐC TẾ'
            WHEN b.cn IN ('exp', 'expat')                   THEN 'exp'
            ELSE 'no'
        END                                                          AS vk,
        -- Không có vùng (region) của ad impression cho ticket → chỉ suy ra VK/QT, còn lại KXĐ
        CASE
            WHEN b.cn ILIKE '%QUOC TE%'   OR b.cn = 'qte'  THEN 'QUỐC TẾ'
            WHEN b.cn ILIKE '%Hai Ngoai%' OR b.cn = 'vki'  THEN 'VIỆT KIỀU'
            ELSE NULL
        END                                                          AS chi_nhanh_inter,
        COALESCE(cns.nhom_dv, b.nhom_dv_raw)                        AS nhom_dv_sys
    FROM base b
    LEFT JOIN LATERAL (
        SELECT nhom_dv
        FROM {{ ref('campaign_name_split') }}
        WHERE UPPER(campain_name_split) = UPPER(b.nhom_dv_raw)
        LIMIT 1
    ) cns ON TRUE
)
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
        ELSE COALESCE(e.chi_nhanh_inter, 'KXĐ')
    END                                                              AS chi_nhanh,
    'KXĐ'::text                                                       AS local_k,
    CASE
        WHEN e.chi_nhanh_inter = 'VIỆT KIỀU' THEN 'VIỆT KIỀU'
        WHEN e.chi_nhanh_inter = 'QUỐC TẾ'  THEN 'QUỐC TẾ'
        ELSE 'Việt Nam'
    END                                                              AS quoc_gia,
    e.sdt::text                                                      AS metric,
    'DealCS'::text                                                   AS type_data,
    e.ticket_id,
    coalesce(e.campaign_name,'KXĐ')::text                            AS campaign,
    coalesce(upc.page_name,'KXĐ')::text                              AS page_name,
    e.page_code::text                                                AS page_id_from_camp,
    e.actor_code::text                                               AS actor_code,
    e.account_fb::text                                               AS account_fb,
    e.nhom_dv_raw::text                                               AS nhom_dv_muc_tieu_code
FROM enriched e
LEFT JOIN {{ ref('ucbt_page_config') }} upc ON upc.page_code = e.page_code
