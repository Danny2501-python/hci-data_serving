-- =============================================================================
-- stg_pts_kangnam_current_products
-- Lấy toàn bộ các dịch vụ hiện tại của Kangnam 
-- =============================================================================
WITH pimp AS (
    SELECT
        *
    FROM {{ source('pre_tns', 'import_product_service_analyst') }}
    WHERE product_category <> 'SAN PHAM'
)
SELECT 
    smhcs.id smhcsid
    ,COALESCE(smhcs.his_service_type, CASE WHEN pp.default_code LIKE 'TDL%' THEN 'Card' end) AS his_service_type
    ,smhcs.surgery_type
    ,smhcsc.product_cat_id product_ctg_id
    ,smhcs.kpi_first_time 
    ,TRIM(COALESCE(
        REGEXP_REPLACE(pc.name, '\s+', ' ', 'g')
        , CASE WHEN smhcs.his_service_type IS NOT NULL THEN 'PTTM KHÁC' 
            WHEN pp.default_code LIKE 'TDL%' THEN 'THẺ DA LIỄU' 
            ELSE 'SAN PHAM' END)) AS product_category
    ,pimp.product_category_paris
    ,pimp.product_category_new
    ,pp.id AS product_id
    ,pp.default_code
    ,TRIM(pt.name) product
    ,pt.list_price
    ,pimp.is_main_service
    ,pimp.group_id
    ,pimp.product_id_kn
    ,pimp.is_vip
    ,pimp.qty_service
    ,CASE WHEN smhcs.kpi_point = 0 THEN null else smhcs.kpi_point end kpi_point
    ,CASE WHEN smhcs.kpi_point_num = 0 THEN 1 ELSE COALESCE(smhcs.kpi_point_num, 1) END kpi_point_num 
    , pt.uom_id
    , uu.name uom
    , pp.create_date
    , GREATEST(pp.write_date, smhcs.write_date) AS write_date
    , CASE WHEN pp.default_code LIKE 'TDL%' THEN 1 
        WHEN COALESCE(pc.name, smhcs.his_service_type) IS null or pc.name ~* 'TPM' THEN NULL 
        WHEN pc.name ~* 'pttm.*mắt' THEN 3 
		WHEN pc.name ~* 'pttm.*mũi' THEN 8
		WHEN pc.name ~* 'ngực|mông' THEN 5
		WHEN pc.name ~* '(pttm.*mỡ)|hút mỡ' THEN 6
		WHEN pc.name ~* 'hàm mặt' THEN 7
		WHEN pc.name ~* 'gội đầu|dưỡng sinh|phun xăm|triệt lô|tắm trắ' OR pc.name = 'ĐIỀU TRỊ MỤN' THEN 2
        WHEN pc.name ~* 'căng (chỉ|da)' THEN 4
		WHEN smhcs.his_service_type in ('Laser', 'Spa') THEN 1
		ELSE 4
	END AS kdtc_product_ctg_id , pp.brand_etl
FROM {{ source('pre_tns', 'sh_medical_health_center_service') }} smhcs
    LEFT JOIN {{ source('pre_tns', 'sh_medical_health_center_service_category') }} smhcsc ON smhcs.service_category = smhcsc.id AND smhcs.brand_etl = smhcsc.brand_etl
    LEFT JOIN {{ source('pre_tns', 'product_category') }} pc ON smhcsc.product_cat_id = pc.id AND smhcs.brand_etl = pc.brand_etl
    RIGHT JOIN {{ source('pre_tns', 'product_product') }} pp ON smhcs.product_id = pp.id AND smhcs.brand_etl = pp.brand_etl
    LEFT JOIN {{ source('pre_tns', 'product_template') }} pt ON pp.product_tmpl_id = pt.id AND pp.brand_etl = pt.brand_etl
    LEFT JOIN {{ source('pre_tns', 'uom_uom') }} uu ON pt.uom_id = uu.id AND uu.brand_etl = pt.brand_etl
    LEFT JOIN pimp ON (CASE WHEN pp.brand_etl < 2 THEN pp.id END) = pimp.product_id 
WHERE pp.brand_etl = 1
