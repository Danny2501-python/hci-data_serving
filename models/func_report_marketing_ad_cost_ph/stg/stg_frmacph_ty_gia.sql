{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_ty_gia — bảng tỷ giá DÙNG CHUNG cho báo cáo Philippines (số VND / 1 đơn vị).
-- Cột: loai_tien, ngay (NULL = áp mọi ngày), ty_gia, nguon ('VND' / 'CO_DINH' / 'ACB').
-- Nơi dùng lấy "dòng ngày gần nhất ≤ ngày cần quy đổi" (ORDER BY ngay DESC NULLS LAST LIMIT 1).
--
-- CÔNG TẮC var('ph_nguon_ty_gia') (mặc định 'co_dinh'):
--   * 'co_dinh' (từ 2026-10-07, theo chỉ đạo của sếp – DÙNG TẠM): 1 con số / loại tiền:
--       USD = 25.806,79 : trung bình tỷ giá MUA CHUYỂN KHOẢN Techcombank
--                         (public.ty_gia_techcombank, 29 ngày 03/09 → 06/10/2026)
--       PHP =    405    : con số cố định do sếp chốt (2026-10-07). Tham khảo: tỷ giá chéo
--                         USD Techcombank ÷ 62,6482 (PHP/USD thị trường) = 411,93 –
--                         Techcombank không niêm yết PHP.
--       AUD = 18.315,78 : tỷ giá chéo = USD Techcombank × 0,7097 (USD/AUD trung bình cùng kỳ)
--   * 'acb' (khi sếp duyệt): tỷ giá ACB theo ngày, bảng public.ty_gia_acb (pipeline
--     data_ops dags/acb_fx, chốt 23:59 giờ VN, có từ 2026-09-10). Giá BÁN CHUYỂN KHOẢN
--     (deal_type = 'ASK', instrument_type = 'TRANSFER') – ACB chỉ niêm yết giá này cho PHP.
--     Bật bằng cách thêm vào dbt_project.yml (vars):  ph_nguon_ty_gia: acb
--   * VND luôn = 1.
-- =============================================================================
{%- set nguon_ty_gia = var('ph_nguon_ty_gia', 'co_dinh') %}
{%- if nguon_ty_gia not in ['co_dinh', 'acb'] %}
  {{ exceptions.raise_compiler_error("ph_nguon_ty_gia phải là 'co_dinh' hoặc 'acb', đang là: " ~ nguon_ty_gia) }}
{%- endif %}
{%- if nguon_ty_gia == 'acb' %}
SELECT 'VND'::text AS loai_tien, NULL::date AS ngay, 1::numeric AS ty_gia, 'VND'::text AS nguon
UNION ALL
SELECT a.loai_tien, a.ngay, a.ty_gia, 'ACB'
FROM {{ source('acb_fx', 'ty_gia_acb') }} a
WHERE a.deal_type = 'ASK'
  AND a.instrument_type = 'TRANSFER'
{%- else %}
SELECT v.loai_tien, v.ngay, v.ty_gia, v.nguon
FROM (VALUES
    ('VND'::text, NULL::date, 1::numeric,      'VND'::text),
    ('USD',       NULL,       25806.79,        'CO_DINH'),
    ('PHP',       NULL,       405,             'CO_DINH'),
    ('AUD',       NULL,       18315.78,        'CO_DINH')
) AS v (loai_tien, ngay, ty_gia, nguon)
{%- endif %}
