-- Đối soát: số phiếu và tổng tiền gốc theo loại tiền trong report_ph_doanh_thu phải bằng
-- đúng ph.account_payment (cùng bộ lọc). Lệch = join bị nhân dòng / mất dòng -> dbt build báo lỗi.
{{ config(severity='error', tags=['phi']) }}

WITH nguon AS (
    SELECT cur.name AS loai_tien,
           count(*) AS so_phieu,
           sum(CASE WHEN p.payment_type = 'outbound' THEN -1 ELSE 1 END * p.amount) AS tong_goc
    FROM {{ source('ph', 'account_payment') }} p
    LEFT JOIN {{ source('ph', 'res_currency') }} cur ON cur.id = p.currency_id
    WHERE p.state = 'posted'
      AND p.brand_etl = 9
      AND p.partner_type = 'customer'
      AND p.payment_type IN ('inbound', 'outbound')
      AND p.payment_date >= '{{ var("ph_go_live_date", "2026-09-10") }}'::date
    GROUP BY 1
),
bao_cao AS (
    SELECT loai_tien, count(*) AS so_phieu, sum(so_tien_goc) AS tong_goc
    FROM {{ ref('report_ph_doanh_thu') }}
    GROUP BY 1
)
SELECT coalesce(n.loai_tien, b.loai_tien) AS loai_tien,
       n.so_phieu AS so_phieu_nguon, b.so_phieu AS so_phieu_bao_cao,
       n.tong_goc AS tong_goc_nguon, b.tong_goc AS tong_goc_bao_cao
FROM nguon n
FULL JOIN bao_cao b ON coalesce(b.loai_tien, '') = coalesce(n.loai_tien, '')
WHERE n.so_phieu IS DISTINCT FROM b.so_phieu
   OR n.tong_goc IS DISTINCT FROM b.tong_goc
