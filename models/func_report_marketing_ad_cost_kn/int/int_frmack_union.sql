-- =============================================================================
-- int_frmack_union  (Pass 11)
-- Union all sources (DC, DS, Lead, Inbox, TC, GG, BK, HL, DealCS) in original order.
-- Directly pulls from stg units to match original Pass 11 structure.
-- =============================================================================

-- DC (Pass 3)

-- crm_base_with_page dùng MATERIALIZED (Postgres 12+): CTE này được UNION lại
-- 5 lần (DC/Lead/TC/BK/HL) ở dưới. Postgres 14 mặc định INLINE CTE thay vì
-- materialize, nên nếu không ép, toàn bộ join bên trong (dim_campaign/
-- dim_account/ucbt_page_config/campaign_name_split LATERAL/stg_frmack_cs_*)
-- bị tính lại từ đầu cho MỖI nhánh UNION — xác nhận qua EXPLAIN (không
-- ANALYZE, chỉ xem plan): "Subquery Scan on crm_base_with_page" xuất hiện
-- đúng 5 lần trước khi thêm MATERIALIZED. Xem README.md mục 17.
WITH crm_base_with_page as MATERIALIZED (
    SELECT
        cb.*,dc.campaign_name,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }} THEN split_part(dc.campaign_name, '_', 2)
        END                                                          AS page_code,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }} THEN split_part(dc.campaign_name, '_', 8)
        END                                                          AS actor_code,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }} THEN split_part(dc.campaign_name, '_', 5)
        END                                                          AS nhom_dv_muc_tieu_code,
        da.account_name                                              AS account_fb,
        mms.service_name                                             AS page_name_ticket
    FROM {{ ref('stg_frmack_crm_base') }} cb
    LEFT JOIN {{ref('dim_camp_adset_ad')}} dcaa ON dcaa.ad_id::text = cb.ad_id::text
    LEFT JOIN {{ ref('dim_campaign') }} dc ON dc.campaign_id::text = dcaa.ad_campaign_id::text
    LEFT JOIN {{ ref('dim_account') }} da ON da.account_id::text = dcaa.account_id::text
    LEFT JOIN (
        SELECT * FROM {{ ref('stg_frmack_cs_tickets') }} WHERE rnk = 1
    ) tcp ON tcp.ticket_id::text = cb.ticket_id::text
    LEFT JOIN (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY service_id ORDER BY created_at DESC) AS rn
        FROM {{ ref('stg_frmack_cs_services') }}
    ) mms ON mms.service_id::text = tcp.service_id::text AND mms.rn = 1
), payment_with_page as (
    SELECT
        ds.*,dc.campaign_name,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }} THEN split_part(dc.campaign_name, '_', 2)
        END                                                          AS page_code,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }} THEN split_part(dc.campaign_name, '_', 8)
        END                                                          AS actor_code,
        CASE
            WHEN split_part(dc.campaign_name, '_', 1) IN {{ var('all_brand_mkt_camp') }} THEN split_part(dc.campaign_name, '_', 5)
        END                                                          AS nhom_dv_muc_tieu_code,
        da.account_name                                              AS account_fb,
        mms.service_name                                             AS page_name_ticket
    FROM {{ ref('stg_frmack_doanh_so') }} ds
    LEFT JOIN {{ref('dim_camp_adset_ad')}} dcaa ON dcaa.ad_id::text = ds.ad_id::text
    LEFT JOIN {{ ref('dim_campaign') }} dc ON dc.campaign_id::text = dcaa.ad_campaign_id::text
    LEFT JOIN {{ ref('dim_account') }} da ON da.account_id::text = dcaa.account_id::text
    LEFT JOIN (
        SELECT * FROM {{ ref('stg_frmack_cs_tickets') }} WHERE rnk = 1
    ) tcp ON tcp.ticket_id::text = ds.ticket_id::text
    LEFT JOIN (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY service_id ORDER BY created_at DESC) AS rn
        FROM {{ ref('stg_frmack_cs_services') }}
    ) mms ON mms.service_id::text = tcp.service_id::text AND mms.rn = 1
    WHERE ds.ngay >= '{{ var("start_date", "2025-08-01") }}'::date
)
SELECT
    vk, ten_dv, "Nguon" AS nguon, "Nhom_nguon" AS nhom_nguon, kenh,
    ngay_den_cua AS ngay, nhom_dv, chi_nhanh_new AS chi_nhanh,
    local_k, quoc_gia, sdt::text AS metric,
    'DC'::text AS type_data, ticket_id,
    coalesce(cbwp.campaign_name,'KXĐ')::text AS campaign,
    coalesce(cbwp.page_name_ticket, upc.page_name,'KXĐ')::text as page_name,
    cbwp.page_code::text as page_id_from_camp,
    cbwp.actor_code::text as actor_code,
    cbwp.account_fb::text as account_fb,
    cbwp.nhom_dv_muc_tieu_code::text as nhom_dv_muc_tieu_code,
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam,
    cbwp.nhom_dv_KH_quan_tam_goc::text as nhom_dv_KH_quan_tam_goc,
    cbwp.nhom_dv_chinh_booking::text as nhom_dv_chinh_booking,
    cbwp.nguon_moi_v2::text as nguon_moi_v2,
    cbwp.nhom_nguon_moi_v2::text as nhom_nguon_moi_v2
FROM crm_base_with_page cbwp
  left join {{ ref('ucbt_page_config') }} upc on cbwp.page_code = upc.page_code
WHERE ngay_den_cua >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 2
  and (reason_cancel_booking not in ('tao_booking_bh') or reason_cancel_booking is null)

UNION ALL
-- DS (Pass 8)
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id,
    coalesce(pwp.campaign_name,'KXĐ')::text AS campaign,
    coalesce(pwp.page_name_ticket, upc.page_name,'KXĐ')::text as page_name,
    pwp.page_code::text as page_id_from_camp,
    pwp.actor_code::text as actor_code,
    pwp.account_fb::text as account_fb,
    pwp.nhom_dv_muc_tieu_code::text as nhom_dv_muc_tieu_code,
    pwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam,
    pwp.nhom_dv_KH_quan_tam_goc::text as nhom_dv_KH_quan_tam_goc,
    pwp.nhom_dv_chinh_booking::text as nhom_dv_chinh_booking,
    pwp.nguon_moi_v2::text as nguon_moi_v2,
    pwp.nhom_nguon_moi_v2::text as nhom_nguon_moi_v2
FROM payment_with_page pwp
  left join {{ ref('ucbt_page_config') }} upc on pwp.page_code = upc.page_code

UNION ALL
-- Lead (Pass 5)
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_tao AS ngay, nhom_dv, chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'Lead', ticket_id,
    coalesce(cbwp.campaign_name,'KXĐ')::text AS campaign,
    coalesce(cbwp.page_name_ticket, upc.page_name,'KXĐ')::text as page_name,
    cbwp.page_code::text as page_id_from_camp,
    cbwp.actor_code::text as actor_code,
    cbwp.account_fb::text as account_fb,
    cbwp.nhom_dv_muc_tieu_code::text as nhom_dv_muc_tieu_code,
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam,
    cbwp.nhom_dv_KH_quan_tam_goc::text as nhom_dv_KH_quan_tam_goc,
    cbwp.nhom_dv_chinh_booking::text as nhom_dv_chinh_booking,
    cbwp.nguon_moi_v2::text as nguon_moi_v2,
    cbwp.nhom_nguon_moi_v2::text as nhom_nguon_moi_v2
FROM crm_base_with_page cbwp
  left join {{ ref('ucbt_page_config') }} upc on cbwp.page_code = upc.page_code
WHERE ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 1

UNION ALL
-- Inbox (Pass 9)
-- Không có liên kết CRM để tra new_source_id, nhưng nhánh này là Inbox
-- Facebook (m_inbox_kangnam) -> mặc định cứng theo catalog utm_source thật
-- của Kangnam (id=751 'Facebook', category 'Online') thay vì NULL.
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, campaign, page_name,page_id::text as page_id_from_camp,
    actor_code::text as actor_code,
    account_fb::text as account_fb,
    nhom_dv_muc_tieu_code::text as nhom_dv_muc_tieu_code,
    null::text as nhom_dv_KH_quan_tam,
    null::text as nhom_dv_KH_quan_tam_goc,
    null::text as nhom_dv_chinh_booking,
    'Facebook'::text as nguon_moi_v2,
    'Online'::text as nhom_nguon_moi_v2
FROM {{ ref('stg_frmack_inbox') }}

UNION ALL
-- TC (Pass 4)
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_den_cua AS ngay, nhom_dv, chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'TC', ticket_id,
    coalesce(cbwp.campaign_name,'KXĐ')::text AS campaign,
    coalesce(cbwp.page_name_ticket, upc.page_name,'KXĐ')::text as page_name,
    cbwp.page_code::text as page_id_from_camp,
    cbwp.actor_code::text as actor_code,
    cbwp.account_fb::text as account_fb,
    cbwp.nhom_dv_muc_tieu_code::text as nhom_dv_muc_tieu_code,
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam,
    cbwp.nhom_dv_KH_quan_tam_goc::text as nhom_dv_KH_quan_tam_goc,
    cbwp.nhom_dv_chinh_booking::text as nhom_dv_chinh_booking,
    cbwp.nguon_moi_v2::text as nguon_moi_v2,
    cbwp.nhom_nguon_moi_v2::text as nhom_nguon_moi_v2
FROM crm_base_with_page cbwp
  left join {{ ref('ucbt_page_config') }} upc on cbwp.page_code = upc.page_code
WHERE ngay_den_cua >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND tong_tien > 0 AND loai_ban_ghi = 2
  and (reason_cancel_booking <> 'tao_booking_bh' or reason_cancel_booking is null)

UNION ALL
-- GG (Pass 10)
-- Không có liên kết CRM, nhưng nhánh này là chi phí quảng cáo Google
-- (cp_google_kangnam) -> mặc định cứng theo catalog utm_source thật của
-- Kangnam (id=755 'Google_Ads', category 'Online') thay vì NULL.
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, campaign, null as page_name,null as page_id_from_camp,
    null as actor_code,
    null as account_fb,
    null as nhom_dv_muc_tieu_code,
    null::text as nhom_dv_KH_quan_tam,
    null::text as nhom_dv_KH_quan_tam_goc,
    null::text as nhom_dv_chinh_booking,
    'Google_Ads'::text as nguon_moi_v2,
    'Online'::text as nhom_nguon_moi_v2
FROM {{ ref('stg_frmack_google') }}

UNION ALL
-- BK (Pass 6)
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_tao AS ngay, nhom_dv, chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'BKHL', ticket_id,
    coalesce(cbwp.campaign_name,'KXĐ')::text AS campaign,
    coalesce(cbwp.page_name_ticket, upc.page_name,'KXĐ')::text as page_name,
    cbwp.page_code::text as page_id_from_camp,
    cbwp.actor_code::text as actor_code,
    cbwp.account_fb::text as account_fb,
    cbwp.nhom_dv_muc_tieu_code::text as nhom_dv_muc_tieu_code,
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam,
    cbwp.nhom_dv_KH_quan_tam_goc::text as nhom_dv_KH_quan_tam_goc,
    cbwp.nhom_dv_chinh_booking::text as nhom_dv_chinh_booking,
    cbwp.nguon_moi_v2::text as nguon_moi_v2,
    cbwp.nhom_nguon_moi_v2::text as nhom_nguon_moi_v2
FROM crm_base_with_page cbwp
  left join {{ ref('ucbt_page_config') }} upc on cbwp.page_code = upc.page_code
WHERE ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 2
  and (reason_cancel_booking <> 'tao_booking_bh' or reason_cancel_booking is null)

UNION ALL
-- HL (Pass 7)
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_hl AS ngay, nhom_dv, chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'HL', ticket_id,
    coalesce(cbwp.campaign_name,'KXĐ')::text AS campaign,
    coalesce(cbwp.page_name_ticket, upc.page_name,'KXĐ')::text as page_name,
    cbwp.page_code::text as page_id_from_camp,
    cbwp.actor_code::text as actor_code,
    cbwp.account_fb::text as account_fb,
    cbwp.nhom_dv_muc_tieu_code::text as nhom_dv_muc_tieu_code,
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam,
    cbwp.nhom_dv_KH_quan_tam_goc::text as nhom_dv_KH_quan_tam_goc,
    cbwp.nhom_dv_chinh_booking::text as nhom_dv_chinh_booking,
    cbwp.nguon_moi_v2::text as nguon_moi_v2,
    cbwp.nhom_nguon_moi_v2::text as nhom_nguon_moi_v2
FROM crm_base_with_page cbwp
  left join {{ ref('ucbt_page_config') }} upc on cbwp.page_code = upc.page_code
WHERE ngay_hl >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 2
  and (reason_cancel_booking <> 'tao_booking_bh' or reason_cancel_booking is null)

UNION ALL
-- DealCS (Caresoft ticket, ad-attributed, metric = số điện thoại)
-- Không có liên kết CRM, nhưng nhánh này chỉ lấy ticket có FB ad_id
-- (stg_frmack_deal: nguon = 'MD - Facebook', kenh = 'FB') -> mặc định cứng
-- theo catalog utm_source thật của Kangnam (id=751 'Facebook', category
-- 'Online') thay vì NULL. Khác với DealCS bên func_report_marketing_ad_cost_pr
-- (nguồn Google Search) — 2 pipeline lấy DealCS theo tiêu chí khác nhau.
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, campaign, page_name, page_id_from_camp,
    actor_code, account_fb, nhom_dv_muc_tieu_code,
    null::text as nhom_dv_KH_quan_tam,
    null::text as nhom_dv_KH_quan_tam_goc,
    null::text as nhom_dv_chinh_booking,
    'Facebook'::text as nguon_moi_v2,
    'Online'::text as nhom_nguon_moi_v2
FROM {{ ref('stg_frmack_deal') }}
