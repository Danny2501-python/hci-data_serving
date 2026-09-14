-- =============================================================================
-- int_frmacpr_erp_conv
-- PASS 9–13: Lead, BK, BKHL, DC, TC từ dữ liệu CRM Paris.
-- Sử dụng lại stg_frmacpr_leads_lines làm base, join thêm metadata.
-- =============================================================================
-- Danh sách ad_account_id THẬT của Paris (lấy động từ cs_facebook_insight
-- brand_etl=3, không hard-code) — dùng để chặn rủi ro lẫn dữ liệu Kangnam khi
-- join dim_camp_adset_ad/dim_campaign (2 bảng build từ cs_facebook_insight
-- KHÔNG lọc brand, xem comment ở CTE base bên dưới).
WITH paris_fb_accounts AS (
    SELECT DISTINCT ad_account_id
    FROM {{ source('paris', 'cs_facebook_insight') }}
    WHERE brand_etl = 3
),
base AS (
    SELECT
        CASE
            WHEN (ss2.org_source ilike '%display%' OR ss2.org_source ilike '%search%') AND ctsda.utm_source ilike '%Google_Search%' THEN 'MD - GoogleAds'
            ELSE ss2.org_source
        END                                                         AS nguon,
        ss2.org_category_code                                       AS nhom_nguon,
        CASE
            WHEN ss2.org_source LIKE '%Facebook%' THEN 'FB'
            WHEN ss2.org_source LIKE '%Seo%'      THEN 'Web'
            WHEN (ss2.org_source ilike '%display%' OR ss2.org_source ilike '%search%') AND ctsda.utm_source ilike '%Google_Search%' THEN 'Google'
            WHEN ss2.org_source LIKE '%Hotline%'  THEN 'Web'
            WHEN ss2.org_source LIKE '%Tiktok%'   THEN 'TikTok'
            ELSE 'Khác'
        END                                                         AS kenh,
        ll.lead_id,
        ll.arrival_date,
        ll.create_date,
        ll.booking_date,
        ll.overseas_vietnamese,
        ll.company_id,
        ll.phone,
        ll.type_crm_id,
        ll.type,
        ll.product_id,
        ll.total_received,
        ll.stage_id,
        ll.brand_etl,
        TRIM(mndap.nhom_dv_cpo)                                    AS nhom_dv,
        CASE
            WHEN ll.overseas_vietnamese = 'marketing' THEN 'Việt Kiều '
            ELSE mrc.name
        END                                                         AS chi_nhanh,
        ecs.name                                                    AS stage_name,
        substring(cta.requester FROM '"phone_no":\s*"(\d+)"') AS phone_no_ticket,
        COALESCE(us.name, monm.new_source_name)                     AS nguon_moi_v2,
        cat.name                                                    AS nhom_nguon_moi_v2,
        -- Chỉ nhận campaign_name khi account_id resolve được thực sự là 1
        -- trong các tài khoản FB của Paris (pfa.ad_account_id IS NOT NULL) —
        -- xem giải thích gotcha "lẫn ad_id giữa brand" ở comment CTE base.
        COALESCE(CASE WHEN pfa.ad_account_id IS NOT NULL THEN dcam.campaign_name END, 'KXĐ')::text AS campaign,
        CASE
            WHEN pfa.ad_account_id IS NOT NULL
             AND SPLIT_PART(dcam.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
                THEN SPLIT_PART(dcam.campaign_name, '_', 8)
        END::text                                                   AS actor_code,
        -- nhom_dv_muc_tieu_code: thêm 2026-09-11, cùng cơ chế nhom_dv_muc_tieu
        -- đã dùng ở func_report_marketing_ad_cost_kn (README.md mục 10) —
        -- token vị trí 5 của campaign_name vừa join, cùng guard pfa/whitelist
        -- với actor_code. Tra ra tên chuẩn qua campaign_name_split ở mart.
        CASE
            WHEN pfa.ad_account_id IS NOT NULL
             AND SPLIT_PART(dcam.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
                THEN SPLIT_PART(dcam.campaign_name, '_', 5)
        END::text                                                   AS nhom_dv_muc_tieu_code,
        -- page_code_raw: thêm 2026-09-11, cùng cơ chế page/page_id đã dùng ở
        -- func_report_marketing_ad_cost_kn (README.md mục 5/7) — token vị trí
        -- 2 của campaign_name vừa join, cùng guard pfa/whitelist. Tra tên qua
        -- ucbt_page_config ở mart (bỏ qua bước ưu tiên "page theo ticket/
        -- service" mà KN có — đơn giản hoá có chủ đích, xem LOGIC.md).
        CASE
            WHEN pfa.ad_account_id IS NOT NULL
             AND SPLIT_PART(dcam.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }}
                THEN SPLIT_PART(dcam.campaign_name, '_', 2)
        END::text                                                   AS page_code_raw,
        -- account_id_raw: account đã verify thuộc Paris (dcaa.account_id, qua
        -- pfa) — tra tên tài khoản qua dim_account ở mart.
        CASE WHEN pfa.ad_account_id IS NOT NULL THEN dcaa.account_id END::text AS account_id_raw,
        -- vk: cờ Việt Kiều đơn giản — dữ liệu overseas_vietnamese của Paris
        -- CHỈ có giá trị 'marketing' cho Việt Kiều (verify 2026-09-11, không có
        -- 'expat'/'mkt_oversea' như bên KN) nên không tách được 'QUỐC TẾ'/'exp'
        -- riêng như KN.
        CASE WHEN ll.overseas_vietnamese = 'marketing' THEN 'VIỆT KIỀU' ELSE 'no' END AS vk,
        -- ten_dv: tên dịch vụ/sản phẩm cụ thể (sp đã join sẵn cho nhom_dv).
        sp.product                                                  AS ten_dv,
        -- local_k_raw/quoc_gia: cùng cơ chế res_country_state/res_country đã
        -- dùng ở KN (stg_frmack_crm_base.sql), qua ll.state_id/country_id.
        CASE
            WHEN rcs.name = 'Thành phố Hồ Chí Minh' THEN 'SÀI GÒN'
            WHEN rcs.name = 'Thành phố Hà Nội'       THEN 'Hà Nội'
            WHEN rcs.name IS NULL                      THEN 'KXĐ'
            WHEN rcs.code NOT LIKE '%VN-%'             THEN 'VIỆT KIỀU'
            ELSE rcs.name
        END                                                          AS local_k_raw,
        rc.name                                                      AS quoc_gia,
        -- nhom_dv_kh_quan_tam/nhom_dv_chinh_booking: bản Paris của 2 model
        -- dùng chung ở common/ (xem stg_dv_khach_hang_quan_tam_paris.sql,
        -- stg_booking_nhom_dich_vu_chinh_paris.sql).
        dkq.first_product_group                                     AS nhom_dv_kh_quan_tam,
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
        END                                                          AS nhom_dv_chinh_booking
    FROM {{ ref('stg_frmacpr_leads_lines') }}               ll
    LEFT JOIN {{ source('paris', 'cs_ticket_api')}}                cta
        ON cta.ticket_id = ll.ticket_id AND cta.brand_id = ll.brand_etl
    LEFT JOIN {{ source('paris', 'cs_ticket_source_api')}}         ctsa
        ON cta.ticket_id = ctsa.ticket_id
    LEFT JOIN {{ source('paris', 'cs_ticket_source_detail_api')}}  ctsda
        ON ctsa.ticket_source_detail_id = ctsda.id
    -- campaign/actor: dim_camp_adset_ad/dim_campaign (models/master_data) build
    -- từ source('public','cs_facebook_insight') KHÔNG lọc brand -> đã bao gồm
    -- sẵn dữ liệu Paris, dùng chung được với func_report_marketing_ad_cost_kn.
    -- Coverage đo thực tế (2026-09-10, Lead/BK/BKHL/DC/TC Paris từ 2025-08-01):
    -- chỉ ~13,5% (11.529/85.153) lead khớp được ad_id -> campaign_name, và một
    -- phần trong số đó vẫn theo campaign convention CŨ (token 1 không thuộc
    -- whitelist all_brand_mkt_camp) nên actor còn thấp hơn. Xem LOGIC.md.
    --
    -- GOTCHA đã verify 2026-09-10: ad_id Facebook KHÔNG đảm bảo tách biệt theo
    -- brand_etl trong cs_facebook_insight — cùng 1 ad_id (thậm chí cùng
    -- ad_campaign_id) có thể xuất hiện đồng thời ở brand_etl=1 (Kangnam) VÀ
    -- brand_etl=3 (Paris). dim_camp_adset_ad dedupe bằng ROW_NUMBER ORDER BY
    -- date DESC (không phân biệt brand) nên có thể trả về account_id của
    -- Kangnam cho 1 ad_id Paris nếu bản ghi Kangnam mới hơn. Join thêm
    -- paris_fb_accounts để CHỈ chấp nhận kết quả khi account_id resolve được
    -- thực sự thuộc Paris — xem CASE WHEN pfa.ad_account_id IS NOT NULL ở
    -- campaign/actor_code phía trên.
    LEFT JOIN {{ ref('dim_camp_adset_ad') }}                        dcaa
           ON dcaa.ad_id::text = SUBSTRING(cta.ad_id_value FROM '\d+')
    LEFT JOIN paris_fb_accounts pfa ON pfa.ad_account_id = dcaa.account_id
    -- dim_campaign dedupe RIÊNG theo ad_campaign_id (không theo account) nên nếu
    -- campaign_id bị trùng chéo brand, dòng "thắng" ORDER BY date DESC có thể
    -- thuộc brand khác dù dcaa/pfa đã xác nhận đúng account Paris. Thêm điều
    -- kiện dcam.ad_account_id = dcaa.account_id để chỉ nhận campaign_name khi
    -- CÙNG account đã verify, chặn tận gốc thay vì chỉ lọc qua pfa phía sau.
    LEFT JOIN {{ ref('dim_campaign') }}                             dcam
           ON dcam.campaign_id::text = dcaa.ad_campaign_id::text
          AND dcam.ad_account_id = dcaa.account_id
    LEFT JOIN {{ source('paris', 'crm_stage') }}            ecs
           ON ecs.id = ll.stage_id AND ecs.brand_etl = 3
    LEFT JOIN {{ source('paris', 'stag_sources') }}         ss1
           ON ss1.old_id = ll.source_id
    LEFT JOIN {{ source('paris', 'stag_sources') }}         ss2
           ON ss2.old_id = ss1.id_pr
    LEFT JOIN {{ source('paris', 'view_stag_products') }}   sp
           ON sp.product_id = ll.product_id AND sp.brand_etl = ll.brand_etl
    LEFT JOIN {{ source('paris', 'm_nhom_dv_adnet_paris') }} mndap
           ON mndap.default_code = sp.default_code AND sp.brand_etl = 3
    LEFT JOIN {{ source('paris', 'm_res_company') }}        mrc
           ON mrc.id = ll.company_id AND mrc.brand_etl = ll.brand_etl
    LEFT JOIN {{ source('paris', 'utm_source') }}           us
           ON us.id = ll.new_source_id AND us.brand_id = ll.brand_etl
    -- Fallback khi crm_lead.new_source_id NULL: suy ra nguồn mới từ nguồn cũ
    -- (ll.source_id) qua bảng mapping master_data.m_utm_source_old_new_map.
    -- LATERAL + ORDER BY new_source_id LIMIT 1 để tránh fan-out (1 số
    -- old_source_id map sang >1 new_source_id — xem LOGIC.md).
    LEFT JOIN LATERAL (
        SELECT new_source_name, new_source_category_id
        FROM {{ ref('m_utm_source_old_new_map') }} m
        WHERE m.old_source_id = ll.source_id AND m.brand_etl = ll.brand_etl
          AND ll.new_source_id IS NULL
        ORDER BY m.new_source_id
        LIMIT 1
    ) monm ON TRUE
    LEFT JOIN {{ source('paris', 'crm_category_source') }}  cat
           ON cat.id = COALESCE(us.category_id, monm.new_source_category_id) AND cat.brand_etl = ll.brand_etl
    LEFT JOIN {{ source('paris', 'res_country_state') }}    rcs
           ON rcs.id = ll.state_id AND rcs.brand_etl = 3
    LEFT JOIN {{ source('paris', 'res_country') }}          rc
           ON rc.id = ll.country_id AND rc.brand_etl = 3
    LEFT JOIN {{ ref('stg_dv_khach_hang_quan_tam_paris') }} dkq
           ON dkq.crm_id = ll.lead_id AND dkq.brand_etl = ll.brand_etl
    LEFT JOIN {{ ref('stg_booking_nhom_dich_vu_chinh_paris') }} sbn
           ON sbn.crm_id = ll.lead_id AND sbn.brand_etl = ll.brand_etl
)

-- Lead (Pass 9)
SELECT nguon, nhom_nguon, kenh,
    create_date::date   AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'Lead'::text        AS type_data,
    nguon_moi_v2, nhom_nguon_moi_v2,
    campaign, actor_code, nhom_dv_muc_tieu_code,
    page_code_raw, NULL::text AS page_id_raw, account_id_raw, vk, ten_dv,
    local_k_raw, quoc_gia, nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM base
WHERE create_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
  AND type = 'lead'
  AND stage_name IN ('Tiềm năng', 'Tham khảo', 'Đặt lịch')

-- Deal Caresoft nguồn google ads
UNION ALL
SELECT
    sfdc.nguon, sfdc.nhom_nguon,    sfdc.kenh,
    sfdc.ngay,  sfdc.nhom_dv,       sfdc.chi_nhanh,
    sfdc.metric,sfdc.type_data,
    -- Không có liên kết CRM để tra new_source_id, nhưng nhánh này CHỈ lấy
    -- Deal Caresoft nguồn Google Search (xem WHERE ctsda.utm_source ilike
    -- '%Google_Search%' trong stg_frmacpr_deal_cs) -> mặc định cứng theo
    -- catalog utm_source thật của Paris (id=735 'Google_Ads', category
    -- 'Online') thay vì để NULL.
    'Google_Ads'::text AS nguon_moi_v2, 'Online'::text AS nhom_nguon_moi_v2,
    sfdc.campaign, sfdc.actor_code, sfdc.nhom_dv_muc_tieu_code,
    -- page_code_raw/account_id_raw/vk/ten_dv/local_k_raw/quoc_gia/
    -- nhom_dv_kh_quan_tam/nhom_dv_chinh_booking: Deal_cs không có liên kết
    -- CRM/FB account (lấy theo tiêu chí Google Search) -> luôn NULL, cùng lý
    -- do campaign/actor_code NULL ở stg_frmacpr_deal_cs.sql.
    NULL::text AS page_code_raw, NULL::text AS page_id_raw, NULL::text AS account_id_raw,
    NULL::text AS vk, NULL::text AS ten_dv,
    NULL::text AS local_k_raw, NULL::text AS quoc_gia,
    NULL::text AS nhom_dv_kh_quan_tam, NULL::text AS nhom_dv_chinh_booking
FROM {{ ref('stg_frmacpr_deal_cs')}} sfdc

UNION ALL
-- BK (Pass 10)
SELECT nguon, nhom_nguon, kenh,
    create_date::date   AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'BK'::text          AS type_data,
    nguon_moi_v2, nhom_nguon_moi_v2,
    campaign, actor_code, nhom_dv_muc_tieu_code,
    page_code_raw, NULL::text AS page_id_raw, account_id_raw, vk, ten_dv,
    local_k_raw, quoc_gia, nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM base
WHERE create_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
  AND type_crm_id = 2

UNION ALL

-- BKHL – Hẹn lịch (Pass 11)
SELECT nguon, nhom_nguon, kenh,
    booking_date::date  AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'BKHL'::text        AS type_data,
    nguon_moi_v2, nhom_nguon_moi_v2,
    campaign, actor_code, nhom_dv_muc_tieu_code,
    page_code_raw, NULL::text AS page_id_raw, account_id_raw, vk, ten_dv,
    local_k_raw, quoc_gia, nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM base
WHERE booking_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
  AND type_crm_id = 2

UNION ALL

-- DC – Đến cửa (Pass 12)
SELECT nguon, nhom_nguon, kenh,
    arrival_date::date  AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'DC'::text          AS type_data,
    nguon_moi_v2, nhom_nguon_moi_v2,
    campaign, actor_code, nhom_dv_muc_tieu_code,
    page_code_raw, NULL::text AS page_id_raw, account_id_raw, vk, ten_dv,
    local_k_raw, quoc_gia, nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM base
WHERE arrival_date::date >= '{{ var("start_date", "2025-08-01") }}'::date

UNION ALL

-- TC – Thành công (Pass 13)
SELECT nguon, nhom_nguon, kenh,
    arrival_date::date  AS ngay,
    nhom_dv, chi_nhanh,
    phone::text         AS metric,
    'TC'::text          AS type_data,
    nguon_moi_v2, nhom_nguon_moi_v2,
    campaign, actor_code, nhom_dv_muc_tieu_code,
    page_code_raw, NULL::text AS page_id_raw, account_id_raw, vk, ten_dv,
    local_k_raw, quoc_gia, nhom_dv_kh_quan_tam, nhom_dv_chinh_booking
FROM base
WHERE arrival_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
  AND total_received > 0
