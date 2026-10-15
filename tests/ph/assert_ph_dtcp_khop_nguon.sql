-- Đối soát báo cáo doanh thu + chi phí Philippines với nguồn, theo từng khoản mục:
--   THU_TIEN / HOAN_TIEN : số dòng + tổng VND = report_ph_doanh_thu
--   QUANG_CAO_FACEBOOK   : tổng VND = cs_facebook_insight (brand 1, campaign 'sun_', từ go-live)
--   VAT_TU_TIEU_HAO      : tổng giá trị gốc = -SUM(stock_valuation_layer.value) (cùng bộ lọc)
-- Lệch = join bị nhân / mất dòng -> dbt build báo lỗi.
{{ config(severity='error', tags=['phi']) }}

WITH bao_cao AS (
    SELECT khoan_muc,
           count(*)                     AS so_dong,
           round(sum(so_tien_vnd))      AS tong_vnd,
           round(sum(so_tien_goc), 2)   AS tong_goc
    FROM {{ ref('report_ph_doanh_thu_chi_phi') }}
    GROUP BY 1
),
nguon AS (
    SELECT CASE WHEN loai_phieu = 'HOAN_TIEN' THEN 'HOAN_TIEN' ELSE 'THU_TIEN' END AS khoan_muc,
           count(*)                     AS so_dong,
           round(sum(doanh_thu_vnd))    AS tong_vnd,
           NULL::numeric                AS tong_goc
    FROM {{ ref('report_ph_doanh_thu') }}
    GROUP BY 1
    UNION ALL
    SELECT 'QUANG_CAO_FACEBOOK', NULL, round(sum(f.spend)::numeric), NULL
    FROM {{ source('kangnam', 'cs_facebook_insight') }} f
    WHERE f.brand_etl = 1
      AND f.ad_campaign_name ILIKE 'sun\_%'
      AND f."date"::date >= '{{ var("ph_go_live_date", "2026-09-10") }}'::date
    UNION ALL
    SELECT 'VAT_TU_TIEU_HAO', NULL, NULL, round(-sum(v.value), 2)
    FROM {{ source('ph', 'stock_valuation_layer') }} v
    JOIN {{ source('ph', 'stock_move') }}          sm ON sm.id = v.stock_move_id
    LEFT JOIN {{ source('ph', 'stock_location') }} ls ON ls.id = sm.location_id
    LEFT JOIN {{ source('ph', 'stock_location') }} ld ON ld.id = sm.location_dest_id
    WHERE v.brand_etl = 9
      AND (v.create_date + interval '8 hours')::date >= '{{ var("ph_go_live_date", "2026-09-10") }}'::date
      AND (   (ls.usage = 'internal' AND ld.usage IN ('production', 'customer', 'inventory'))
           OR (ld.usage = 'internal' AND ls.usage IN ('production', 'customer', 'inventory')))
)
SELECT coalesce(n.khoan_muc, b.khoan_muc) AS khoan_muc,
       n.so_dong AS so_dong_nguon, b.so_dong AS so_dong_bao_cao,
       n.tong_vnd AS tong_vnd_nguon, b.tong_vnd AS tong_vnd_bao_cao,
       n.tong_goc AS tong_goc_nguon, b.tong_goc AS tong_goc_bao_cao
FROM nguon n
FULL JOIN bao_cao b ON b.khoan_muc = n.khoan_muc
WHERE (n.so_dong  IS NOT NULL AND n.so_dong  IS DISTINCT FROM b.so_dong)
   OR (n.tong_vnd IS NOT NULL AND n.tong_vnd IS DISTINCT FROM b.tong_vnd)
   OR (n.tong_goc IS NOT NULL AND n.tong_goc IS DISTINCT FROM b.tong_goc)
   OR (n.khoan_muc IS NULL AND b.so_dong > 0)
   OR (b.khoan_muc IS NULL AND (coalesce(n.so_dong, 0) > 0 OR coalesce(n.tong_vnd, 0) <> 0 OR coalesce(n.tong_goc, 0) <> 0))
