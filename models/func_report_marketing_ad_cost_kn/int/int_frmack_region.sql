-- =============================================================================
-- int_frmack_region  (Pass 12)
-- Compute tinh_noi (normalize local_k) and region (from ggs_region_map).
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
    FROM {{ ref('int_frmack_union') }}
)
SELECT
    r.*,
    CASE WHEN r.tinh_noi = 'Bà Rịa - Vũng Tàu' THEN 'Hồ Chí Minh và lân cận'
         WHEN r.tinh_noi ILIKE '%Lào Cai%'       THEN 'Miền Bắc mở rộng'
         WHEN r.tinh_noi ILIKE '%Yên Bái%'       THEN 'Miền Bắc mở rộng'
         WHEN r.tinh_noi ILIKE '%Huế%'           THEN 'Đà nẵng lân cận'
         WHEN r.tinh_noi = 'KXĐ'                 THEN 'KXĐ'
         ELSE grm.region
    END AS region
FROM re_map r
LEFT JOIN {{ source('kangnam', 'ggs_region_map') }} grm
       ON grm.location = r.tinh_noi::text
