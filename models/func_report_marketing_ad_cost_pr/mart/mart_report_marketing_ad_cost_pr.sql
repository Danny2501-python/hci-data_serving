{{
  config(
    materialized = 'table',
    alias        = 'report_marketing_ad_cost_pr_v2'
  )
}}
-- =============================================================================
-- mart_report_marketing_ad_cost_pr  (Final output)
-- Ghi đè toàn bộ bảng report_marketing_ad_cost_pr_v2 mỗi lần chạy.
-- Đây là model table duy nhất trong pipeline Paris.
-- =============================================================================

-- paris_pages/paris_accounts_named: bản dedupe CHỈ trong phạm vi Paris
-- (brand_etl=3) của cs_facebook_insight, thay thế dim_page/dim_account (dùng
-- chung toàn tập đoàn, không lọc brand — xem gotcha giải thích ở dưới, ngay
-- trước 2 JOIN dùng các CTE này). Viết dạng CTE dedupe 1 lần (giống cách
-- paris_fb_accounts ở int_frmacpr_erp_conv.sql) thay vì LATERAL scan theo
-- từng dòng — LATERAL trực tiếp trên cs_facebook_insight (~500K dòng) cho
-- mỗi dòng trong ~512K dòng output sẽ quá chậm (đã thử, phải huỷ vì chạy quá
-- lâu); CTE dedupe trước rồi JOIN thường (hash join) nhanh hơn nhiều bậc.
WITH paris_pages AS (
    SELECT DISTINCT ON (facebook_page_id) facebook_page_id, page_name
    FROM {{ source('paris', 'cs_facebook_insight') }}
    WHERE brand_etl = 3 AND facebook_page_id IS NOT NULL
    ORDER BY facebook_page_id, date DESC
),
paris_accounts_named AS (
    SELECT DISTINCT ON (ad_account_id) ad_account_id, ad_account_name
    FROM {{ source('paris', 'cs_facebook_insight') }}
    WHERE brand_etl = 3 AND ad_account_id IS NOT NULL
    ORDER BY ad_account_id, date DESC
),
resolved AS (
    SELECT
        u.*,
        -- tinh_noi_raw: chuẩn hoá local_k_raw (bỏ tiền tố "Tỉnh"/"Thành phố",
        -- gộp case đặc biệt) — cùng regex đã dùng ở
        -- func_report_marketing_ad_cost_kn (int_frmack_region.sql).
        CASE WHEN u.local_k_raw ~~* '%thành phố%'
                 THEN regexp_replace(u.local_k_raw, '^Thành phố\s*', '')
             WHEN u.local_k_raw ~~* '%Tỉnh%'
                 THEN regexp_replace(u.local_k_raw, '^Tỉnh\s*', '')
             WHEN u.local_k_raw ~~ '%Bà Rịa%'
                 THEN 'Bà Rịa – Vũng Tàu'
             WHEN u.local_k_raw ~~* '%VIỆT KIỀU%'
                 THEN 'VIỆT KIỀU'
             ELSE u.local_k_raw
        END AS tinh_noi_raw
    FROM {{ ref('int_frmacpr_union') }} u
)
SELECT
    r.nguon,
    r.nhom_nguon,
    r.kenh,
    r.ngay::timestamp AS "date",
    r.nhom_dv,
    r.chi_nhanh,
    r.metric  AS "dt",
    r.type_data,
    -- product_type: thêm 2026-09-24 — chỉ có giá trị khi type_data = 'DS':
    -- 'service' = Doanh số Dịch vụ, 'cosmetic' = Doanh số Sản phẩm (xem
    -- stg_frmacpr_doanh_so.sql). NULL cho mọi type_data khác — không
    -- COALESCE 'KXĐ' để tránh nhầm là 1 loại doanh số.
    r.product_type,
    -- product_category: thêm 2026-09-24 — view_stag_products.product_category
    -- (vd NIỀNG RĂNG MẮC CÀI KHÁC, CẤY GHÉP IMPLANT, RĂNG SỨ, SAN PHAM...).
    -- Có giá trị ở Lead/BK/BKHL/DC/TC/DS (cùng phạm vi ten_dv); để NULL ở các
    -- type_data khác, không COALESCE 'KXĐ' — cùng cách với product_type.
    r.product_category,
    r.nguon_moi_v2,
    r.nhom_nguon_moi_v2,
    r.campaign,
    COALESCE(r.actor_code, 'KXĐ') AS actor,
    -- nhom_dv_muc_tieu: thêm 2026-09-11, cùng cơ chế đã dùng ở
    -- func_report_marketing_ad_cost_kn (README.md mục 10) — tra
    -- nhom_dv_muc_tieu_code (token vị trí 5 của campaign_name, đã tách sẵn ở
    -- tầng dưới) qua campaign_name_split (case-insensitive) để ra tên chuẩn.
    -- Độc lập với cột nhom_dv hiện có (nguồn khác, xem LOGIC.md). Luôn
    -- COALESCE(...,'KXĐ') — nhất quán với actor/campaign ở model này.
    COALESCE(cns_mt.nhom_dv, 'KXĐ') AS nhom_dv_muc_tieu,
    -- Cụm cột thêm 2026-09-11 — đối chiếu func_report_marketing_ad_cost_kn,
    -- xem LOGIC.md mục "Bổ sung cụm cột đối chiếu KN" để biết chi tiết nguồn/
    -- coverage/giới hạn từng cột. Luôn COALESCE(...,'KXĐ') — nhất quán với
    -- campaign/actor/nhom_dv_muc_tieu ở model này (khác KN, nơi một số cột để
    -- raw NULL ở vài stream).
    COALESCE(r.vk, 'KXĐ') AS vk,
    COALESCE(r.ten_dv, 'KXĐ') AS ten_dv,
    COALESCE(r.local_k_raw, 'KXĐ') AS local_k,
    COALESCE(r.tinh_noi_raw, 'KXĐ') AS tinh_noi,
    CASE WHEN r.tinh_noi_raw = 'Bà Rịa - Vũng Tàu'      THEN 'Hồ Chí Minh và lân cận'
         WHEN r.tinh_noi_raw ILIKE '%Lào Cai%'          THEN 'Miền Bắc mở rộng'
         WHEN r.tinh_noi_raw ILIKE '%Yên Bái%'          THEN 'Miền Bắc mở rộng'
         WHEN r.tinh_noi_raw ILIKE '%Huế%'              THEN 'Đà nẵng lân cận'
         WHEN r.tinh_noi_raw IS NULL OR grm.region IS NULL THEN 'KXĐ'
         ELSE grm.region
    END AS region,
    COALESCE(r.quoc_gia, 'KXĐ') AS quoc_gia,
    COALESCE(ccm.continent, 'KXĐ') AS chau_luc,
    COALESCE(dp.page_name, upc.page_name, 'KXĐ') AS page,
    COALESCE(r.page_id_raw, r.page_code_raw, 'KXĐ') AS page_id,
    COALESCE(da.ad_account_name, 'KXĐ') AS account_fb,
    COALESCE(r.nhom_dv_kh_quan_tam, 'KXĐ') AS nhom_dv_kh_quan_tam,
    COALESCE(r.nhom_dv_chinh_booking, 'KXĐ') AS nhom_dv_chinh_booking
FROM resolved r
LEFT JOIN LATERAL (
    SELECT nhom_dv FROM {{ source('paris', 'campaign_name_split') }}
    WHERE UPPER(campain_name_split) = UPPER(r.nhom_dv_muc_tieu_code) LIMIT 1
) cns_mt ON TRUE
-- region: ggs_region_map (bảng dùng chung với KN, location->miền) — các case
-- đặc biệt "Hồ Chí Minh và lân cận"/"Miền Bắc mở rộng"/"Đà nẵng lân cận" vốn
-- hiệu chỉnh theo mạng lưới chi nhánh KN, giữ nguyên để tái dùng logic có
-- sẵn, cần rà soát lại nếu miền/phân vùng kinh doanh của Paris khác KN.
LEFT JOIN {{ source('paris', 'ggs_region_map') }} grm
       ON grm.location = r.tinh_noi_raw
-- chau_luc: ucbt_country_continent (dùng chung với KN, không brand-scoped).
LEFT JOIN {{ source('paris', 'ucbt_country_continent') }} ccm
       ON ccm.country = r.quoc_gia
-- page: 2 nguồn tra song song, không xung đột vì khác namespace giá trị —
-- page_id_raw (Cost_fb_cd/th/ib) và page_code_raw (Lead/BK/BKHL/DC/TC/DS,
-- token vị trí 2 của campaign_name, tra qua ucbt_page_config — đã verify
-- 2026-09-11 page_code Paris luôn có tiền tố riêng "pr..." (prfb/prtk/przl/
-- prig), KHÔNG trùng brand khác, an toàn không cần lọc thêm).
--
-- GOTCHA phát hiện 2026-09-11 (vá ngay khi thêm): KHÔNG dùng dim_page/
-- dim_account (models/master_data) cho page_id_raw/account_id_raw — 2 bảng
-- này build từ cs_facebook_insight KHÔNG lọc brand và dedupe THUẦN theo
-- page_id/account_id (ROW_NUMBER ORDER BY date DESC, không phân biệt brand),
-- CÙNG LỚP RỦI RO đã vá cho dim_campaign ở int_frmacpr_erp_conv.sql. Verify
-- thực tế: facebook_page_id VÀ ad_account_id đều CÓ trùng chéo giữa
-- brand_etl=1 (Kangnam) và brand_etl=3 (Paris) trong cs_facebook_insight (vd.
-- ad_account_id='act_1741025749489548' — chính account PR dùng để phân biệt
-- Cost_fb_th — cũng xuất hiện ở brand_etl=1). Tra qua dim_page/dim_account
-- hiện tại "may mắn" vẫn ra đúng tên Paris (đã kiểm 3 page_id ví dụ), nhưng
-- không an toàn về lâu dài (Kangnam có dữ liệu mới hơn có thể làm page/
-- account_fb của Paris âm thầm đổi thành tên Kangnam) — giống hệt lý do đã
-- vá dim_campaign. Fix: bỏ qua dim_page/dim_account, JOIN thẳng vào
-- paris_pages/paris_accounts_named (CTE dedupe ở đầu file, CHỈ trong phạm vi
-- Paris) thay vì bảng dùng chung không lọc brand.
LEFT JOIN paris_pages dp ON dp.facebook_page_id = r.page_id_raw
LEFT JOIN LATERAL (
    SELECT page_name FROM {{ source('paris', 'ucbt_page_config') }}
    WHERE page_code = r.page_code_raw LIMIT 1
) upc ON TRUE
-- account_fb: cùng fix gotcha như page ở trên — JOIN paris_accounts_named
-- thay vì dim_account (dùng chung, không lọc brand). account_id_raw ở nhóm
-- CRM đã qua verify pfa/paris_fb_accounts ở tầng dưới (chắc chắn là 1 trong
-- các account Paris), nên lọc brand_etl=3 ở đây chỉ là lớp bảo vệ thứ 2,
-- không đổi kết quả; ở nhóm Cost_fb_cd/th đây là lớp bảo vệ DUY NHẤT (trước
-- đây không có).
LEFT JOIN paris_accounts_named da ON da.ad_account_id = r.account_id_raw
