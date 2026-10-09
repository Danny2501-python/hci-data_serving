{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_nhom_dv_map — bảng tra mã nhóm dịch vụ (token 5 tên campaign) → nhóm DV
-- dùng cho dự án Philippines. 1 dòng / mã (không phân biệt hoa thường, bỏ khoảng trắng).
-- Ưu tiên: seed riêng PH `campaign_name_split_ph` (sandbox_ph) > seed chung
-- `campaign_name_split` (dùng chung với Kangnam – KHÔNG sửa bảng chung).
-- Giữ tên cột campain_name_split / nhom_dv như seed chung để thay thế trực tiếp.
-- Thêm 2026-10-08.
-- =============================================================================
SELECT DISTINCT ON (upper(trim(campain_name_split)))
    trim(campain_name_split) AS campain_name_split,
    nhom_dv
FROM (
    SELECT campain_name_split, nhom_dv, 1 AS uu_tien FROM {{ ref('campaign_name_split_ph') }}
    UNION ALL
    SELECT campain_name_split, nhom_dv, 2 AS uu_tien FROM {{ ref('campaign_name_split') }}
) x
WHERE nullif(trim(campain_name_split), '') IS NOT NULL
ORDER BY upper(trim(campain_name_split)), uu_tien
