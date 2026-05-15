WITH prepped AS (
    SELECT * FROM {{ ref('int_crm_line_prep') }}
),
state_calc AS (
    SELECT 
        *,
        -- Tương đương hàm check_state_deposit() trong Python
        -- Thứ tự WHEN phải TUYỆT ĐỐI giống thứ tự key từ 1->11 trong dict_class
        CASE
            WHEN stage = 'done' AND total_received >= total AND COALESCE(number_used_old, 0) = 0 THEN 'done_newsys' -- 1
            WHEN stage_old = 'done' THEN 'done' -- 2
            WHEN total = 0 THEN 'total_zero' -- 3
            WHEN total_received = 0 THEN 'received_new_zero' -- 4
            WHEN COALESCE(number_used_old, 0) = 0 AND (COALESCE(number_used, 0) > 0 OR COALESCE(total_received, 0) > 0) THEN 'deposit_not_used' -- 5
            WHEN total_received_old >= total_old AND total_old > 0 THEN 'deposit_full' -- 6
            WHEN COALESCE(total_received, 0) + COALESCE(total_received_old, 0) > total_old THEN 'deposit_sync_inc' -- 7
            WHEN total_received > 0 AND COALESCE(capd_clineid, 0) = 0 AND total_received >= COALESCE(total_received_old, 0) THEN 'deposit_sync' -- 8
            WHEN COALESCE(number_used_old, 0) = 0 AND total_old > total THEN 'new_not_discount' -- 9
            WHEN total_received_old < total_old AND total_old < total_before_discount_old THEN 'deposit_with_discount' -- 10
            WHEN total_received_old < total_old THEN 'deposit' -- 11
            ELSE NULL
        END AS state_deposit
    FROM prepped
)

SELECT
    brand_etl, crm_id, product_id, clineid, capd_clineid,
    first_date_payment, last_rnk_clineid_pmdate,
    state_deposit,

    -- 1. Tương đương dfl['total_new'] (Đổi tên ngay thành total theo logic rename cuối Python)
    CASE 
        WHEN state_deposit IN ('done','deposit_with_discount','received_new_zero','deposit_full','deposit_sync_inc') THEN total_old 
        ELSE total 
    END AS total,
    total AS total_curr, -- Đẩy tên cũ thành _curr

    -- 2. Tương đương dfl['total_received_new'] (Logic np.select)
    CASE
        WHEN state_deposit IN ('done','deposit_full') OR (COALESCE(capd_clineid, 0) = 0 AND total_received < total) THEN total_received_old
        WHEN state_deposit IN ('deposit_sync','deposit_not_used','done_newsys','deposit_sync_inc') THEN total_received
        ELSE COALESCE(total_received, 0) + COALESCE(total_received_old, 0)
    END AS total_received,
    total_received AS total_received_curr,

    -- 3. Tương đương dfl['quantity_new']
    CASE WHEN COALESCE(number_used_old, 0) > 0 THEN quantity_old ELSE quantity END AS quantity,
    quantity AS quantity_curr,

    -- 4. Tương đương dfl['number_used_new']
    COALESCE(number_used_old, 0) + COALESCE(number_used, 0) AS number_used,
    number_used AS number_used_curr,

    -- 5. Tương đương dfl['stage_new']
    CASE WHEN COALESCE(stage_old, '') = 'done' THEN 'done' ELSE stage END AS stage,
    stage AS stage_curr,

    -- 6. Tương đương dfl['uom_price_new']
    uom_price,
    uom_price AS uom_price_curr

FROM state_calc