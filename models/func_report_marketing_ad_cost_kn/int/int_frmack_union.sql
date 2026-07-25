-- =============================================================================
-- int_frmack_union  (Pass 11)
-- Union all sources (DC, DS, Lead, Inbox, TC, GG, BK, HL, DealCS) in original order.
-- Directly pulls from stg units to match original Pass 11 structure.
-- =============================================================================

-- DC (Pass 3)

WITH crm_base_with_page as (
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
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam
FROM crm_base_with_page cbwp
  left join {{source('kangnam','ucbt_page_config')}} upc on cbwp.page_code = upc.page_code
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
    pwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam
FROM payment_with_page pwp
  left join {{source('kangnam','ucbt_page_config')}} upc on pwp.page_code = upc.page_code

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
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam
FROM crm_base_with_page cbwp
  left join {{source('kangnam','ucbt_page_config')}} upc on cbwp.page_code = upc.page_code
WHERE ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 1

UNION ALL
-- Inbox (Pass 9)
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, campaign, page_name,page_id::text as page_id_from_camp,
    actor_code::text as actor_code,
    account_fb::text as account_fb,
    nhom_dv_muc_tieu_code::text as nhom_dv_muc_tieu_code,
    null::text as nhom_dv_KH_quan_tam
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
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam
FROM crm_base_with_page cbwp
  left join {{source('kangnam','ucbt_page_config')}} upc on cbwp.page_code = upc.page_code
WHERE ngay_den_cua >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND tong_tien > 0 AND loai_ban_ghi = 2
  and (reason_cancel_booking <> 'tao_booking_bh' or reason_cancel_booking is null)

UNION ALL
-- GG (Pass 10)
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, campaign, null as page_name,null as page_id_from_camp,
    null as actor_code,
    null as account_fb,
    null as nhom_dv_muc_tieu_code,
    null::text as nhom_dv_KH_quan_tam
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
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam
FROM crm_base_with_page cbwp
  left join {{source('kangnam','ucbt_page_config')}} upc on cbwp.page_code = upc.page_code
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
    cbwp.nhom_dv_KH_quan_tam::text as nhom_dv_KH_quan_tam
FROM crm_base_with_page cbwp
  left join {{source('kangnam','ucbt_page_config')}} upc on cbwp.page_code = upc.page_code
WHERE ngay_hl >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 2
  and (reason_cancel_booking <> 'tao_booking_bh' or reason_cancel_booking is null)

UNION ALL
-- DealCS (Caresoft ticket, ad-attributed, metric = số điện thoại)
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, campaign, page_name, page_id_from_camp,
    actor_code, account_fb, nhom_dv_muc_tieu_code,
    null::text as nhom_dv_KH_quan_tam
FROM {{ ref('stg_frmack_deal') }}
