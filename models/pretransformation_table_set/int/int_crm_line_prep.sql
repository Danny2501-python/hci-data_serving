WITH dfl AS (
    SELECT 
        *,
        -- Tương đương: dfl.groupby(['brand_etl','crm_id','product_id'])['clineid'].transform('nunique')
        COUNT(clineid) OVER (PARTITION BY brand_etl, crm_id, product_id) AS count_line_samep
    FROM {{ ref('stg_pts_stag_crm_line_sync') }}
),
his_line_deposit AS (
    SELECT *
    FROM {{ ref('stg_pts_crm_line_deposit_history') }}
    WHERE count_line_samep = 1 -- Lọc trước giống Pandas
),
df_fdate AS (
    SELECT *
    FROM {{ ref('stg_pts_stag_payment_1st_date') }}
    WHERE rn_product = 1
)

SELECT
    dfl.brand_etl, dfl.crm_id, dfl.product_id, dfl.clineid, dfl.capd_clineid,
    
    -- Tương đương logic: dfl.update(info_crm_pd[ls_col_old])
    -- Nếu count=1 ở cả 2 bảng, lấy dữ liệu từ his_line_deposit đè lên dữ liệu _old
    CASE WHEN dfl.count_line_samep = 1 AND his.crm_id_old IS NOT NULL THEN his.total ELSE dfl.total_old END AS total_old,
    CASE WHEN dfl.count_line_samep = 1 AND his.crm_id_old IS NOT NULL THEN his.total_received ELSE dfl.total_received_old END AS total_received_old,
    CASE WHEN dfl.count_line_samep = 1 AND his.crm_id_old IS NOT NULL THEN his.quantity ELSE dfl.quantity_old END AS quantity_old,
    CASE WHEN dfl.count_line_samep = 1 AND his.crm_id_old IS NOT NULL THEN his.uom_price ELSE dfl.uom_price_old END AS uom_price_old,
    CASE WHEN dfl.count_line_samep = 1 AND his.crm_id_old IS NOT NULL THEN his.number_used ELSE dfl.number_used_old END AS number_used_old,
    CASE WHEN dfl.count_line_samep = 1 AND his.crm_id_old IS NOT NULL THEN his.stage ELSE dfl.stage_old END AS stage_old,
    CASE WHEN dfl.count_line_samep = 1 AND his.crm_id_old IS NOT NULL THEN his.total_before_discount ELSE dfl.total_before_discount_old END AS total_before_discount_old,

    -- Tương đương: dfl[['first_date_payment', 'last_rnk_clineid_pmdate']] = info_pm[...]
    fdate.first_date_payment,
    fdate.last_rnk_clineid_pmdate,

    -- Các cột hiện tại giữ nguyên
    dfl.quantity, dfl.uom_price, dfl.number_used, dfl.total, dfl.total_received, dfl.stage

FROM dfl
LEFT JOIN his_line_deposit his
    ON dfl.brand_etl = his.brand_etl AND dfl.crm_id = his.crm_id AND dfl.product_id = his.product_id
LEFT JOIN df_fdate fdate
    ON dfl.brand_etl = fdate.brand_etl AND dfl.crm_id = fdate.crm_id AND dfl.product_id = fdate.product_id