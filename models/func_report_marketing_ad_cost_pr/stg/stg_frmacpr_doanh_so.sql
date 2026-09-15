-- =============================================================================
-- stg_frmacpr_doanh_so
-- PASS 6: Doanh số (DS) thanh toán cho Paris.
-- =============================================================================
-- Danh sách ad_account_id THẬT của Paris (lấy động từ cs_facebook_insight
-- brand_etl=3) — chặn rủi ro lẫn dữ liệu Kangnam khi join dim_camp_adset_ad/
-- dim_campaign (2 bảng build từ cs_facebook_insight KHÔNG lọc brand, xem
-- comment ở dưới).
WITH paris_fb_accounts AS (
    SELECT DISTINCT ad_account_id
    FROM {{ source('paris', 'cs_facebook_insight') }}
    WHERE brand_etl = 3
)
SELECT
    CASE
       WHEN (ss2.org_source ilike '%display%' OR ss2.org_source ilike '%search%') AND ctsda.utm_source ilike '%Google_Search%' THEN 'MD - GoogleAds'
       ELSE ss2.org_source
    END                                                             AS nguon,
    ss2.org_category_code                                           AS nhom_nguon,
    CASE
        WHEN ss2.org_source LIKE '%Facebook%' THEN 'FB'
        WHEN ss2.org_source LIKE '%Seo%'      THEN 'Web'
        WHEN (ss2.org_source ilike '%display%' OR ss2.org_source ilike '%search%') 
              AND ctsda.utm_source ilike '%Google_Search%' THEN 'Google'
        WHEN ss2.org_source LIKE '%Hotline%'  THEN 'Web'
        WHEN ss2.org_source LIKE '%Tiktok%'  THEN 'TikTok'
        ELSE 'Khác'
    END                                                             AS kenh,
    spt.payment_date::date                                          AS ngay,
    TRIM(mndap.nhom_dv_cpo)                                         AS nhom_dv,
    CASE
        WHEN cl.overseas_vietnamese = 'marketing' THEN 'Việt Kiều'
        ELSE mrc.name
    END                                                             AS chi_nhanh,
    spt.payment::text                                               AS metric,
    'DS'::text                                                      AS type_data,
    COALESCE(us.name, monm.new_source_name)                         AS nguon_moi_v2,
    cat.name                                                        AS nhom_nguon_moi_v2,
    -- Chỉ nhận campaign_name khi account_id resolve được thực sự là 1 trong
    -- các tài khoản FB của Paris (pfa.ad_account_id IS NOT NULL) — xem gotcha
    -- "lẫn ad_id giữa brand" ở comment JOIN dim_camp_adset_ad bên dưới.
    COALESCE(CASE WHEN pfa.ad_account_id IS NOT NULL THEN dcam.campaign_name END, 'KXĐ')::text AS campaign,
    CASE
        WHEN pfa.ad_account_id IS NOT NULL
         AND SPLIT_PART(dcam.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN SPLIT_PART(dcam.campaign_name, '_', 8)
    END::text                                                       AS actor_code,
    -- nhom_dv_muc_tieu_code: xem giải thích đầy đủ ở int_frmacpr_erp_conv.sql
    -- (cùng cơ chế nhom_dv_muc_tieu của func_report_marketing_ad_cost_kn).
    CASE
        WHEN pfa.ad_account_id IS NOT NULL
         AND SPLIT_PART(dcam.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN SPLIT_PART(dcam.campaign_name, '_', 5)
    END::text                                                       AS nhom_dv_muc_tieu_code,
    -- page_code_raw/account_id_raw/vk/ten_dv/local_k_raw/quoc_gia/
    -- nhom_dv_kh_quan_tam/nhom_dv_chinh_booking: xem giải thích đầy đủ ở
    -- int_frmacpr_erp_conv.sql (cùng cơ chế).
    CASE
        WHEN pfa.ad_account_id IS NOT NULL
         AND SPLIT_PART(dcam.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
            THEN SPLIT_PART(dcam.campaign_name, '_', 2)
    END::text                                                       AS page_code_raw,
    NULL::text                                                      AS page_id_raw,
    CASE WHEN pfa.ad_account_id IS NOT NULL THEN dcaa.account_id END::text AS account_id_raw,
    CASE WHEN cl.overseas_vietnamese = 'marketing' THEN 'VIỆT KIỀU' ELSE 'no' END AS vk,
    sp.product                                                      AS ten_dv,
    CASE
        WHEN rcs.name = 'Thành phố Hồ Chí Minh' THEN 'SÀI GÒN'
        WHEN rcs.name = 'Thành phố Hà Nội'       THEN 'Hà Nội'
        WHEN rcs.name IS NULL                      THEN 'KXĐ'
        WHEN rcs.code NOT LIKE '%VN-%'             THEN 'VIỆT KIỀU'
        ELSE rcs.name
    END                                                              AS local_k_raw,
    rc.name                                                          AS quoc_gia,
    dkq.first_product_group                                         AS nhom_dv_kh_quan_tam,
    CASE
        WHEN sbn.nhom_dich_vu_chinh IS NULL THEN NULL
        WHEN sbn.nhom_dich_vu_chinh = 'BEAUTY & SPA' THEN '8.BEAUTY & SPA'
        WHEN sbn.nhom_dich_vu_chinh = 'PTTM HÀM MẶT' THEN '3.HÀM MẶT/NHA KHOA'
        WHEN sbn.nhom_dich_vu_chinh = 'WELLNESS' THEN '9.WELLNESS'
        WHEN sbn.nhom_dich_vu_chinh = 'BÉO ĐA CHUYÊN KHOA' THEN '7.BÉO ĐA CHUYÊN KHOA'
        WHEN sbn.nhom_dich_vu_chinh = 'PTTM MẮT' THEN '1.MẮT'
        WHEN sbn.nhom_dich_vu_chinh = 'PTTM MŨI' THEN '2.MŨI'
        WHEN sbn.nhom_dich_vu_chinh = 'CẤY MỠ' THEN '5.CẤY MỠ'
        WHEN sbn.nhom_dich_vu_chinh = 'PTTM NGỰC/MÔNG' THEN '4.NGỰC/MÔNG'
        ELSE '6.DỊCH VỤ KHÁC'
    END                                                              AS nhom_dv_chinh_booking
FROM {{ source('paris', 'stag_payment_transfer') }}            spt
LEFT JOIN {{ source('paris', 'crm_lead') }}                    cl
       ON cl.id = spt.crm_id AND cl.brand_etl = spt.brand_etl
LEFT JOIN {{ source('paris', 'cs_ticket_api')}}                cta
       ON cta.ticket_id = cl.ticket_id AND cta.brand_id = cl.brand_etl
LEFT JOIN {{ source('paris', 'cs_ticket_source_api')}}         ctsa
       ON cta.ticket_id = ctsa.ticket_id
LEFT JOIN {{ source('paris', 'cs_ticket_source_detail_api')}}  ctsda
       ON ctsa.ticket_source_detail_id = ctsda.id
-- campaign/actor: dim_camp_adset_ad/dim_campaign (models/master_data) build từ
-- source('public','cs_facebook_insight') KHÔNG lọc brand -> đã bao gồm sẵn dữ
-- liệu Paris, dùng chung được với func_report_marketing_ad_cost_kn. Coverage
-- đo thực tế (2026-09-10, DS Paris từ 2025-08-01): chỉ ~3,4% (1.446/42.583)
-- payment khớp được ad_id -> campaign_name, do phần lớn cs_ticket_api.ad_id_value
-- NULL hoặc crm_lead không map được ticket. Xem LOGIC.md.
--
-- GOTCHA đã verify 2026-09-10: ad_id Facebook KHÔNG đảm bảo tách biệt theo
-- brand_etl trong cs_facebook_insight — cùng 1 ad_id (thậm chí cùng
-- ad_campaign_id) có thể xuất hiện đồng thời ở brand_etl=1 (Kangnam) VÀ
-- brand_etl=3 (Paris). dim_camp_adset_ad dedupe bằng ROW_NUMBER ORDER BY date
-- DESC (không phân biệt brand) nên có thể trả về account_id của Kangnam cho 1
-- ad_id Paris nếu bản ghi Kangnam mới hơn. Join thêm paris_fb_accounts để CHỈ
-- chấp nhận kết quả khi account_id resolve được thực sự thuộc Paris.
LEFT JOIN {{ ref('dim_camp_adset_ad') }}                        dcaa
       ON dcaa.ad_id::text = SUBSTRING(cta.ad_id_value FROM '\d+')
LEFT JOIN paris_fb_accounts pfa ON pfa.ad_account_id = dcaa.account_id
-- dim_campaign dedupe RIÊNG theo ad_campaign_id (không theo account) nên nếu
-- campaign_id bị trùng chéo brand, dòng "thắng" ORDER BY date DESC có thể
-- thuộc brand khác dù dcaa/pfa đã xác nhận đúng account Paris. Thêm điều kiện
-- dcam.ad_account_id = dcaa.account_id để chỉ nhận campaign_name khi CÙNG
-- account đã verify, chặn tận gốc thay vì chỉ lọc qua pfa phía sau.
LEFT JOIN {{ ref('dim_campaign') }}                             dcam
       ON dcam.campaign_id::text = dcaa.ad_campaign_id::text
      AND dcam.ad_account_id = dcaa.account_id
LEFT JOIN {{ source('paris', 'view_stag_products') }}          sp
       ON sp.product_id = spt.product_id AND sp.brand_etl = spt.brand_etl
LEFT JOIN {{ source('paris', 'stag_sources') }}                ss1
       ON ss1.old_id = cl.source_id
LEFT JOIN {{ source('paris', 'stag_sources') }}                ss2
       ON ss2.old_id = ss1.id_pr
LEFT JOIN {{ source('paris', 'm_nhom_dv_adnet_paris') }}       mndap
       ON mndap.default_code = sp.default_code AND sp.brand_etl = 3
LEFT JOIN {{ source('paris', 'm_res_company') }}               mrc
       ON mrc.id = cl.company_id AND mrc.brand_etl = cl.brand_etl
LEFT JOIN {{ source('paris', 'utm_source') }}                  us
       ON us.id = cl.new_source_id AND us.brand_id = cl.brand_etl
-- Fallback khi crm_lead.new_source_id NULL — xem int_frmacpr_erp_conv.sql
-- cho giải thích đầy đủ về gotcha fan-out và bảng mapping dùng chung.
LEFT JOIN LATERAL (
    SELECT new_source_name, new_source_category_id
    FROM {{ ref('m_utm_source_old_new_map') }} m
    WHERE m.old_source_id = cl.source_id AND m.brand_etl = cl.brand_etl
      AND cl.new_source_id IS NULL
    ORDER BY m.new_source_id
    LIMIT 1
) monm ON TRUE
LEFT JOIN {{ source('paris', 'crm_category_source') }}         cat
       ON cat.id = COALESCE(us.category_id, monm.new_source_category_id) AND cat.brand_etl = cl.brand_etl
LEFT JOIN {{ source('paris', 'res_country_state') }}            rcs
       ON rcs.id = cl.state_id AND rcs.brand_etl = 3
LEFT JOIN {{ source('paris', 'res_country') }}                  rc
       ON rc.id = cl.country_id AND rc.brand_etl = 3
LEFT JOIN {{ ref('stg_dv_khach_hang_quan_tam_paris') }}         dkq
       ON dkq.crm_id = cl.id AND dkq.brand_etl = cl.brand_etl
LEFT JOIN {{ ref('stg_booking_nhom_dich_vu_chinh_paris') }}     sbn
       ON sbn.crm_id = cl.id AND sbn.brand_etl = cl.brand_etl
WHERE spt.brand_etl = 3
  AND spt.payment_date >= '{{ var("start_date", "2025-08-01") }}'::date
