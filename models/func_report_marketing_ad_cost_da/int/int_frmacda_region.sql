{{
  config(
    materialized = 'ephemeral'
  )
}}

-- =============================================================================
-- int_frmacda_region — bản ĐÔNG Á của int_frmack_region (Kangnam), logic giữ
-- nguyên: chuẩn hoá tinh_noi từ local_k, tra region qua ggs_region_map.
-- =============================================================================

WITH re_map AS (
    SELECT *,
           CASE WHEN local_k ~~* '%thành phố%'
                    THEN regexp_replace(local_k, '^Thành phố\s*', '')::varchar
                WHEN local_k ~~* '%Tỉnh%'
                    THEN regexp_replace(local_k, '^Tỉnh\s*', '')::varchar
                WHEN local_k ~~ '%Bà Rịa%'
                    THEN 'Bà Rịa – Vũng Tàu'::varchar
                WHEN local_k ~~* '%VIỆT KIỀU%'
                    THEN 'VIỆT KIỀU'::varchar
                ELSE local_k::varchar
           END AS tinh_noi
    FROM {{ ref('int_frmacda_union') }}
)
SELECT
    r.*,
    CASE WHEN r.tinh_noi = 'Bà Rịa - Vũng Tàu'          THEN 'Hồ Chí Minh và lân cận'
         WHEN r.tinh_noi ILIKE '%Lào Cai%'              THEN 'Miền Bắc mở rộng'
         WHEN r.tinh_noi ILIKE '%Yên Bái%'              THEN 'Miền Bắc mở rộng'
         WHEN r.tinh_noi ILIKE '%Huế%'                  THEN 'Đà nẵng lân cận'
         WHEN r.tinh_noi = 'KXĐ' OR grm.region IS NULL  THEN 'KXĐ'
         ELSE grm.region
    END AS region
FROM re_map r
LEFT JOIN {{ source('kangnam', 'ggs_region_map') }} grm
       ON grm.location = r.tinh_noi::text
