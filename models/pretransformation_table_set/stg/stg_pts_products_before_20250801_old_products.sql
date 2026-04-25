-- =============================================================================
-- stg_pts_products_before_20250801_old_products
-- Lấy toàn bộ các dịch vụ trong bảng stag_products có create_date trước ngày 20250801
-- =============================================================================
SELECT 
    smhcsid
    ,product_id
    ,his_service_type
    ,surgery_type
    ,product_category
    ,product_category_paris
    ,product_category_new
    ,default_code
    ,product
    ,list_price
    ,group_id
    ,kpi_point
    ,kpi_point_num
    ,product_id_kn
    ,product_ctg_id
    ,is_main_service
    ,uom_id	
    ,uom
    ,is_no_kpi
    ,kdtc_product_ctg_id
    ,create_date
    ,write_date
    ,is_vip
    ,kpi_first_time
    ,gr_bh_id
    ,qty_service
    ,pr_product_id
    ,hh_product_id
    ,sci_product_id
FROM {{ source('pre_tns', 'stag_products') }}
WHERE create_date < '2025-08-01'