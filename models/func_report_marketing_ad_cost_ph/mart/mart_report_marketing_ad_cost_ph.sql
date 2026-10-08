{{
  config(
    materialized = 'table',
    schema       = 'sandbox_ph',
    alias        = 'report_marketing_ad_cost_ph',
    tags         = ['report_ph', 'phi']
  )
}}
-- =============================================================================
-- mart_report_marketing_ad_cost_ph — báo cáo chi phí & hiệu quả marketing PHILIPPINES
-- Cùng 26 cột, cùng tên/thứ tự với report_marketing_ad_cost_kn_v2 (để Tableau chỉ cần
-- đổi nguồn bảng) + 4 cột thêm ở cuối: trang_thai_du_lieu, ly_do, lead_id, nguon_he_thong.
--   Cost_fb_cd / inbox : campaign 'sun_' (brand 1, hạ tầng FB Kangnam)
--   Lead/BKHL/HL/DC/TC/DS : ERP Philippines (schema ph, brand 9)
-- Không có Google / DealCS (PH chưa có dữ liệu tương ứng).
-- [2026-10-08] Dòng DS dùng stg_frmacph_doanh_so_thu (amount × tỷ giá theo loại tiền) thay cho
-- stg_frmacph_doanh_so (amount_vnd – SAI với phiếu PHP, đã xoá) → bảng này và bản _thu ra cùng
-- doanh số; _thu chỉ thêm 4 cột tỷ giá. Không còn bảng nào mang số sai.
-- =============================================================================
WITH fb AS (
    SELECT * FROM {{ ref('stg_frmacph_fb_cost') }}
),
page_map AS (           -- page_id → tên page, lấy từ chính dữ liệu chi phí 'sun_'
    SELECT page_id, max(page_name) AS page_name FROM fb GROUP BY page_id
),
camp_acc AS (           -- campaign_id → tên tài khoản quảng cáo (dùng cho inbox)
    SELECT campaign_id, max(account_fb) AS account_fb FROM fb GROUP BY campaign_id
),
crm AS (
    SELECT c.*, tt.trang_thai_du_lieu, tt.ly_do
    FROM {{ ref('stg_frmacph_crm_base') }} c
    LEFT JOIN {{ ref('stg_frmacph_trang_thai') }} tt ON tt.lead_id = c.lead_id
),
crm_rows AS (
    SELECT crm.*, 'Lead'::text AS type_data, crm.ngay_tao     AS ngay FROM crm WHERE loai_ban_ghi = 1 AND ngay_tao IS NOT NULL
    UNION ALL
    SELECT crm.*, 'BKHL',                    crm.ngay_tao             FROM crm WHERE loai_ban_ghi = 2 AND ngay_tao IS NOT NULL
    UNION ALL
    SELECT crm.*, 'HL',                      crm.ngay_hl              FROM crm WHERE loai_ban_ghi = 2 AND ngay_hl IS NOT NULL
    UNION ALL
    SELECT crm.*, 'DC',                      crm.ngay_den_cua         FROM crm WHERE loai_ban_ghi = 2 AND ngay_den_cua IS NOT NULL
    UNION ALL
    SELECT crm.*, 'TC',                      crm.ngay_den_cua         FROM crm WHERE loai_ban_ghi = 2 AND ngay_den_cua IS NOT NULL AND tong_tien > 0
)

-- ── Stream 1: chi phí Facebook ───────────────────────────────────────────────
SELECT
    CASE WHEN f.cn = 'vki' THEN 'VIỆT KIỀU' WHEN f.cn = 'qte' THEN 'QUỐC TẾ'
         WHEN f.cn IN ('exp','expat') THEN 'exp' ELSE 'no' END           AS vk,
    'DV'::text                                                           AS ten_dv,
    'CP'::text                                                           AS "Nguon",
    'CP'::text                                                           AS "Nhom_nguon",
    'FB'::text                                                           AS kenh,
    f.ngay                                                               AS "date",
    coalesce(cns.nhom_dv, 'KXĐ')::text                                   AS nhom_dv,
    'SUNWOO MEDICAL CENTER'::text                                        AS chi_nhanh,
    coalesce(fc.continent_vn, 'KXĐ')::text                               AS local_k,
    coalesce(fc.country_name_vn, 'KXĐ')::text                            AS quoc_gia,
    ccm.continent::text                                                  AS chau_luc,
    f.chi_phi::text                                                      AS "Metric",
    'Cost_fb_cd'::text                                                   AS type_data,
    coalesce(f.page_name, 'KXĐ')::text                                   AS page,
    f.page_id::text                                                      AS page_id,
    coalesce(upper(ccm.continent), 'KXĐ')::text                          AS region,
    coalesce(f.region, 'KXĐ')::text                                      AS tinh_noi,
    f.camp_name::text                                                    AS campaign,
    f.account_fb::text                                                   AS account_fb,
    coalesce(nullif(f.actor_code, ''), 'KXĐ')::text                      AS actor,
    coalesce(cns.nhom_dv, 'KXĐ')::text                                   AS nhom_dv_muc_tieu,
    NULL::text                                                           AS nhom_dv_kh_quan_tam,
    NULL::text                                                           AS nhom_dv_kh_quan_tam_goc,
    NULL::text                                                           AS nhom_dv_chinh_booking,
    'Facebook'::text                                                     AS nguon_moi_v2,
    'Online'::text                                                       AS nhom_nguon_moi_v2,
    'THAT'::text                                                         AS trang_thai_du_lieu,
    'Chi phí quảng cáo FB thực tế'::text                                 AS ly_do,
    NULL::int                                                            AS lead_id,
    'FB brand 1 (campaign sun_)'::text                                   AS nguon_he_thong
FROM fb f
LEFT JOIN {{ source('kangnam', 'fb_country_code_mapping') }} fc ON fc.country_code = f.country
LEFT JOIN {{ ref('ucbt_country_continent') }} ccm ON ccm.country = fc.country_name_vn
LEFT JOIN LATERAL (
    SELECT nhom_dv FROM {{ ref('campaign_name_split') }}
    WHERE upper(campain_name_split) = upper(f.nhom_dv_code) LIMIT 1
) cns ON TRUE

UNION ALL
-- ── Stream 2: inbox ─────────────────────────────────────────────────────────
SELECT
    CASE WHEN i.cn = 'vki' THEN 'VIỆT KIỀU' WHEN i.cn = 'qte' THEN 'QUỐC TẾ'
         WHEN i.cn IN ('exp','expat') THEN 'exp' ELSE 'no' END,
    'DV', 'IB', 'IB', 'FB',
    i.ngay,
    coalesce(cns.nhom_dv, 'KXĐ'),
    'SUNWOO MEDICAL CENTER',
    coalesce(i.vung, 'KXĐ'),
    'QUỐC TẾ',                                   -- m_inbox chỉ có vùng, không có quốc gia (giống KN)
    NULL,
    i.inbox_moi::text,
    'inbox',
    coalesce(upc.page_name, 'KXĐ'),
    coalesce(upc.page_id::text, 'KXĐ'),
    'KXĐ',
    coalesce(i.vung, 'KXĐ'),
    i.camp_name,
    coalesce(ca.account_fb, 'KXĐ'),
    coalesce(nullif(i.actor_code, ''), 'KXĐ'),
    coalesce(cns.nhom_dv, 'KXĐ'),
    NULL, NULL, NULL,
    'Facebook', 'Online',
    'THAT', 'Inbox FB thực tế', NULL, 'FB brand 1 (campaign sun_)'
FROM {{ ref('stg_frmacph_inbox') }} i
LEFT JOIN {{ ref('ucbt_page_config') }} upc ON upc.page_code = i.page_code
LEFT JOIN camp_acc ca ON ca.campaign_id = i.campaign_id
LEFT JOIN LATERAL (
    SELECT nhom_dv FROM {{ ref('campaign_name_split') }}
    WHERE upper(campain_name_split) = upper(i.nhom_dv_code) LIMIT 1
) cns ON TRUE

UNION ALL
-- ── Stream 3: Lead / BKHL / HL / DC / TC (ERP PH) – Metric = SĐT ─────────────
SELECT
    r.vk, r.ten_dv, r.nguon, r.nhom_nguon, r.kenh,
    r.ngay,
    r.nhom_dv,
    coalesce(r.chi_nhanh, 'KXĐ'),
    r.local_k,
    coalesce(r.quoc_gia, 'KXĐ'),
    ccm.continent,
    r.sdt,
    r.type_data,
    coalesce(pm.page_name, 'KXĐ'),
    coalesce(r.page_id, 'KXĐ'),
    coalesce(upper(ccm.continent), 'KXĐ'),
    r.local_k,
    'KXĐ', 'KXĐ', 'KXĐ', 'KXĐ',                   -- campaign/account/actor/nhóm DV mục tiêu: ERP PH không lưu campaign FB
    'KXĐ', 'KXĐ', 'KXĐ',
    coalesce(r.nguon_moi_v2, 'KXĐ'),
    coalesce(r.nhom_nguon_moi_v2, 'KXĐ'),
    coalesce(r.trang_thai_du_lieu, 'NGHI_TEST'),
    coalesce(r.ly_do, 'Không phân loại được'),
    r.lead_id,
    'ERP PH brand 9'
FROM crm_rows r
LEFT JOIN page_map pm ON pm.page_id = r.page_id
LEFT JOIN {{ ref('ucbt_country_continent') }} ccm ON ccm.country = r.quoc_gia
WHERE r.nhom_dv <> 'SAN PHAM'

UNION ALL
-- ── Stream 4: DS – doanh số (phiếu thu đã ghi sổ, quy đổi VND theo tỷ giá) ──
SELECT
    coalesce(c.vk, 'KXĐ'), coalesce(c.ten_dv, 'DV'), coalesce(c.nguon, 'KXĐ'), coalesce(c.nhom_nguon, 'KXĐ'),
    coalesce(c.kenh, 'Khác'),
    d.ngay,
    coalesce(c.nhom_dv, 'KXĐ'),
    coalesce(d.chi_nhanh, 'KXĐ'),
    coalesce(c.local_k, 'KXĐ'),
    coalesce(c.quoc_gia, 'KXĐ'),
    ccm.continent,
    d.doanh_so::text,
    'DS',
    coalesce(pm.page_name, 'KXĐ'),
    coalesce(c.page_id, 'KXĐ'),
    coalesce(upper(ccm.continent), 'KXĐ'),
    coalesce(c.local_k, 'KXĐ'),
    'KXĐ', 'KXĐ', 'KXĐ', 'KXĐ',
    'KXĐ', 'KXĐ', 'KXĐ',
    coalesce(c.nguon_moi_v2, 'KXĐ'),
    coalesce(c.nhom_nguon_moi_v2, 'KXĐ'),
    coalesce(tt.trang_thai_du_lieu, 'NGHI_TEST'),
    coalesce(tt.ly_do, 'Phiếu thu không gắn lead'),
    d.lead_id,
    'ERP PH brand 9'
FROM {{ ref('stg_frmacph_doanh_so_thu') }} d
LEFT JOIN crm c                                     ON c.lead_id  = d.lead_id
LEFT JOIN {{ ref('stg_frmacph_trang_thai') }} tt    ON tt.lead_id = d.lead_id
LEFT JOIN page_map pm                               ON pm.page_id = c.page_id
LEFT JOIN {{ ref('ucbt_country_continent') }} ccm   ON ccm.country = c.quoc_gia
