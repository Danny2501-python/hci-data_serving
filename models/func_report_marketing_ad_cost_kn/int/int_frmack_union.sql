-- =============================================================================
-- int_frmack_union  (Pass 11)
-- Union all sources (DC, DS, Lead, Inbox, TC, GG, BK, HL) in original order.
-- Directly pulls from stg units to match original Pass 11 structure.
-- =============================================================================

-- DC (Pass 3)
SELECT
    vk, ten_dv, "Nguon" AS nguon, "Nhom_nguon" AS nhom_nguon, kenh,
    ngay_den_cua AS ngay, nhom_dv, chi_nhanh_new AS chi_nhanh,
    local_k, quoc_gia, sdt::text AS metric,
    'DC'::text AS type_data, ticket_id, 'campaign'::text AS campaign, null as page_name,null as page_id_from_camp
FROM {{ ref('stg_frmack_crm_base') }}
WHERE ngay_den_cua >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 2

UNION ALL
-- DS (Pass 8)
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, 'campaign', null as page_name,null as page_id_from_camp
FROM {{ ref('stg_frmack_doanh_so') }}

UNION ALL
-- Lead (Pass 5)
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_tao AS ngay, nhom_dv, chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'Lead', ticket_id, 'campaign', null as page_name,null as page_id_from_camp
FROM {{ ref('stg_frmack_crm_base') }}
WHERE ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 1

UNION ALL
-- Inbox (Pass 9)
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, 'campaign', page_name,page_id::text as page_id_from_camp
FROM {{ ref('stg_frmack_inbox') }}

UNION ALL
-- TC (Pass 4)
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_den_cua AS ngay, nhom_dv, chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'TC', ticket_id, 'campaign', null as page_name,null as page_id_from_camp
FROM {{ ref('stg_frmack_crm_base') }}
WHERE ngay_den_cua >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND tong_tien > 0 AND loai_ban_ghi = 2

UNION ALL
-- GG (Pass 10)
SELECT
    vk, ten_dv, nguon, nhom_nguon, kenh, ngay,
    nhom_dv, chi_nhanh, local_k, quoc_gia, metric,
    type_data, ticket_id, campaign, null as page_name,null as page_id_from_camp
FROM {{ ref('stg_frmack_google') }}

UNION ALL
-- BK (Pass 6)
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_tao AS ngay, nhom_dv, chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'BKHL', ticket_id, 'campaign', null as page_name,null as page_id_from_camp
FROM {{ ref('stg_frmack_crm_base') }}
WHERE ngay_tao >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 2

UNION ALL
-- HL (Pass 7)
SELECT
    vk, ten_dv, "Nguon", "Nhom_nguon", kenh,
    ngay_hl AS ngay, nhom_dv, chi_nhanh_new,
    local_k, quoc_gia, sdt::text,
    'HL', ticket_id, 'campaign', null as page_name,null as page_id_from_camp
FROM {{ ref('stg_frmack_crm_base') }}
WHERE ngay_hl >= '{{ var("start_date", "2025-08-01") }}'::date
  AND nhom_dv <> 'SAN PHAM' AND loai_ban_ghi = 2
