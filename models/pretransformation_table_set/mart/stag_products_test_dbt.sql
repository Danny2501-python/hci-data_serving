{{
  config(
    materialized = 'table',
    alias        = 'stag_products_test_dbt'
  )
}}
-- =============================================================================
-- stag_products_test_dbt (Final output)
-- Ghi đè toàn bộ bảng stag_products_test_dbt mỗi lần chạy.
-- =============================================================================
WITH explode_null_kpi as (
    SELECT 
        product_id
        ,REPLACE(UNNEST(string_to_array(product_id_kn,',')),'.0','')::INT AS kn_ref_id
    FROM {{ ref('int_pts_all_products_for_updating') }} 
    WHERE kpi_point IS NULL
        AND COALESCE(product_id_kn,'') NOT IN ('','0.0','0')
),
kpi_calculation AS (
    SELECT 
        enki.product_id
        ,SUM(ipkpfu.kpi_point) AS total_kpi_point
    FROM explode_null_kpi enki
    LEFT JOIN {{ ref('int_pts_all_products_for_updating')}} ipkpfu 
        ON enki.kn_ref_id = ipkpfu.product_id
    WHERE ipkpfu.product_id IS NOT NULL
    GROUP BY enki.product_id
)
SELECT
    ipkpfu2.smhcsid                 ,ipkpfu2.product_id             ,ipkpfu2.his_service_type       ,ipkpfu2.surgery_type       ,ipkpfu2.product_category
    ,ipkpfu2.product_category_paris ,ipkpfu2.product_category_new   ,ipkpfu2.default_code           ,ipkpfu2.product            ,ipkpfu2.list_price
    ,ipkpfu2.group_id::text         
    ,CASE 
        WHEN COALESCE(ipkpfu2.kpi_point,0) = 0 THEN kc.total_kpi_point 
        ELSE ipkpfu2.kpi_point 
    END as kpi_point
    ,ipkpfu2.kpi_point_num          ,ipkpfu2.product_id_kn          ,ipkpfu2.product_ctg_id
    ,ipkpfu2.is_main_service        ,ipkpfu2.uom_id                 ,ipkpfu2.uom                    ,ipkpfu2.is_no_kpi          ,ipkpfu2.kdtc_product_ctg_id
    ,ipkpfu2.create_date            ,ipkpfu2.write_date             ,ipkpfu2.is_vip                 ,ipkpfu2.kpi_first_time     
    ,CASE 
        WHEN ipkpfu2.gr_bh_id is not null then ipkpfu2.gr_bh_id
        WHEN ipkpfu2.product_ctg_id IN (411,454,1334,1336,1394) OR ipkpfu2.product ~* '(tàn nhang| nám |ban vàng| chàm |u tuyến bã|trị.*đồi mồi|bớt (sùi)?)' THEN 2
        WHEN ipkpfu2.product_ctg_id IN (419,466,1345,1396) OR ipkpfu2.product ~* 'mụn (thịt|cơm)|tẩy nốt ruồi' THEN 3
        WHEN ipkpfu2.product_ctg_id IN (424,425,475,485,1344,1361,426,1302,1351) OR ipkpfu2.product ~* '(xóa (hình )?xăm|phun (môi|mày|mí|thêu)|điêu khắc|hair stro)' THEN 4
        WHEN ipkpfu2.product_ctg_id IN (428,484,1350) OR ipkpfu2.product ~* 'triệt (lông|râu|ria)' THEN 5
        WHEN ipkpfu2.product ~* '(botox|botul|(nhăn|mặt).*aller)' THEN 6
        WHEN ipkpfu2.his_service_type IN ('Laser','Spa') THEN 1
        ELSE NULL
    END AS gr_bh_id
    ,ipkpfu2.qty_service            ,ipkpfu2.pr_product_id          ,ipkpfu2.hh_product_id          ,ipkpfu2.sci_product_id 
FROM {{ ref('int_pts_all_products_for_updating') }} ipkpfu2
    LEFT JOIN kpi_calculation kc ON kc.product_id = ipkpfu2.product_id
    