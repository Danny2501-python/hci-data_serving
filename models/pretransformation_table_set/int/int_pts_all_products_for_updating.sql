--=================================================================
-- stg_pts_kangnam_products_for_updating
-- Bảng dịch vụ Kangnam cần cập nhật vào model 
-- =================================================================
WITH no_kpi_prd
AS (
    SELECT 
        product_id 
    FROM {{ source('pre_tns', 'import_no_kpi_service') }} 
)
SELECT 
    smhcsid                 ,product_id             ,his_service_type       ,surgery_type       ,product_category
    ,product_category_paris ,product_category_new   ,default_code           ,product            ,list_price
    ,group_id::text         ,kpi_point              ,kpi_point_num          ,product_id_kn      ,product_ctg_id
    ,is_main_service        ,uom_id                 ,uom    
    ,CASE WHEN product_id IN (SELECT product_id FROM no_kpi_prd) THEN true ELSE NULL END as is_no_kpi  
    ,kdtc_product_ctg_id
    ,create_date            ,write_date             ,is_vip                 ,kpi_first_time     ,null::int as gr_bh_id 
    ,qty_service            
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as pr_product_id  
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as hh_product_id  
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as sci_product_id 
FROM {{ ref('stg_pts_kangnam_current_products') }}
UNION ALL 
SELECT 
    smhcsid                 ,product_id             ,his_service_type       ,surgery_type       ,product_category
    ,product_category_paris ,product_category_new   ,default_code           ,product            ,list_price
    ,group_id::text         ,kpi_point              ,kpi_point_num          ,product_id_kn      ,product_ctg_id
    ,is_main_service        ,uom_id                 ,uom    
    ,CASE WHEN product_id IN (SELECT product_id FROM no_kpi_prd) THEN true ELSE NULL END as is_no_kpi  
    ,kdtc_product_ctg_id
    ,create_date            ,write_date             ,is_vip                 ,kpi_first_time     ,null::int as gr_bh_id 
    ,qty_service            
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as pr_product_id  
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as hh_product_id  
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as sci_product_id 
FROM {{ ref('stg_pts_paris_current_products') }}
UNION ALL 
SELECT 
    smhcsid                 ,product_id             ,his_service_type       ,surgery_type       ,product_category
    ,product_category_paris ,product_category_new   ,default_code           ,product            ,list_price
    ,group_id::text         ,kpi_point              ,kpi_point_num          ,product_id_kn      ,product_ctg_id
    ,is_main_service        ,uom_id                 ,uom    
    ,CASE WHEN product_id IN (SELECT product_id FROM no_kpi_prd) THEN true ELSE NULL END as is_no_kpi  
    ,kdtc_product_ctg_id
    ,create_date            ,write_date             ,is_vip                 ,kpi_first_time     ,null::int as gr_bh_id 
    ,qty_service            
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as pr_product_id  
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as hh_product_id  
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as sci_product_id 
FROM {{ ref('stg_pts_hongha_current_products') }}
UNION ALL 
SELECT 
    smhcsid                 ,product_id             ,his_service_type       ,surgery_type       ,product_category
    ,product_category_paris ,product_category_new   ,default_code           ,product            ,list_price
    ,group_id::text         ,kpi_point              ,kpi_point_num          ,product_id_kn      ,product_ctg_id
    ,is_main_service        ,uom_id                 ,uom    
    ,CASE WHEN product_id IN (SELECT product_id FROM no_kpi_prd) THEN true ELSE NULL END as is_no_kpi  
    ,kdtc_product_ctg_id
    ,create_date            ,write_date             ,is_vip                 ,kpi_first_time     ,null::int as gr_bh_id 
    ,qty_service            
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as pr_product_id  
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as hh_product_id  
    ,CASE WHEN create_date < '2025-08-01' THEN product_id else null END as sci_product_id 
FROM {{ ref('stg_pts_sci_current_products') }}
UNION ALL 
SELECT  
    smhcsid                 ,product_id             ,his_service_type       ,surgery_type       ,product_category
    ,product_category_paris ,product_category_new   ,default_code           ,product            ,list_price
    ,group_id::text         ,kpi_point              ,kpi_point_num          ,product_id_kn      ,product_ctg_id
    ,is_main_service        ,uom_id                 ,uom                    ,is_no_kpi          ,kdtc_product_ctg_id
    ,create_date            ,write_date             ,is_vip                 ,kpi_first_time     ,gr_bh_id
    ,qty_service            ,pr_product_id          ,hh_product_id          ,sci_product_id 
FROM {{ ref('stg_pts_old_products_not_in_current') }}