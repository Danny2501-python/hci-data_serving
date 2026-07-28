{{
  config(
    materialized = 'view'
  )
}}

WITH cline as (
    SELECT 
        cl.id as crm_id,
        cl.name as code_booking,
        cl.code_customer,
        cln.brand_etl,
        cln.id as cline_id,
        cln.stage,
        sp.product as cline_service_name,
        sp.product_category as cline_product_category,
        CASE
            WHEN cl.customer_come = 'yes' then cl.arrival_date + interval '7 hours'
            else cl.booking_date + interval '7 hours'
        END as booking_report_date,
        cln.create_date + interval '7 hours' as cline_created_date,
        spt.payment_date as cline_payment_date,
        spt.total_payment as cline_total_payment,
        CASE
            WHEN sp.his_service_type = 'Surgery' then 'PTTM'
            WHEN sp.his_service_type IN ('Spa','Laser','Card') then 'Beauty & Spa'
            WHEN sp.his_service_type = 'Odontology' then 'Nha khoa'
            WHEN sp.his_service_type = 'wellness' then 'Wellness'
            WHEN sp.his_service_type = 'weight_loss' then 'Weight Loss'
            ELSE 'Khác'
        END as business_line
    FROM {{ source('crm_base', 'crm_line') }} cln
        left join {{ source('crm_base', 'crm_lead') }} cl on cl.id = cln.crm_id and cl.brand_etl = cln.brand_etl
        left join (
            SELECT clineid, brand_etl, MIN(payment_date) as payment_date, SUM(payment) as total_payment
            FROM {{ source('crm_base', 'stag_payment_transfer') }}
            GROUP BY clineid, brand_etl
        ) spt on spt.clineid = cln.id and spt.brand_etl = cln.brand_etl
        left join {{ source('crm_base', 'view_stag_products') }} sp on sp.product_id = cln.product_id and sp.brand_etl = cln.brand_etl
    WHERE cl.id in (SELECT crm_id FROM {{ ref('stg_booking_id_co_tien_tc') }})
        AND cl.type = 'opportunity'
), rnk_bl_cline as (
    -- LƯU Ý: nhiều cline trong cùng 1 booking có thể có cline_created_date GIỐNG HỆT NHAU (tạo
    -- cùng 1 batch) -> mọi ORDER BY cline_created_date đều phải kèm cline_id làm tiêu chí phụ để
    -- thứ tự ổn định, tái lập được giữa các lần chạy (nếu không, ROW_NUMBER()/FIRST_VALUE() sẽ
    -- chọn ngẫu nhiên dòng "đầu tiên" trong nhóm trùng giờ, gây sai lệch main_bl_customer/main_bl_bk).
    select cln.*,
        ROW_NUMBER() OVER (PARTITION BY cln.business_line, cln.code_customer ORDER BY cln.cline_created_date, cln.cline_id) as cus_bl_cline_order,
        ROW_NUMBER() OVER (PARTITION BY cln.crm_id ORDER BY cln.cline_created_date, cln.cline_id) as crm_cline_order,
        ROW_NUMBER() OVER (PARTITION BY cln.code_customer ORDER BY cln.cline_created_date, cln.cline_id) as cus_cline_order
    from cline cln
    WHERE cln.brand_etl = 1
), paid_bl_cline as (
    -- Chỉ các dòng có payment > 0, đánh số thứ tự riêng theo (business_line, code_customer) để
    -- xác định "lần mua có payment đầu tiên" và tính khoảng cách 6 tháng, bỏ qua các dòng không
    -- phát sinh payment (hủy/chưa thanh toán) khi đếm thứ tự và khi tìm dòng liền trước.
    select
        cline_id,
        code_customer,
        business_line,
        cline_payment_date,
        ROW_NUMBER() OVER (PARTITION BY business_line, code_customer ORDER BY cline_created_date, cline_id) as cus_bl_paid_order
    from rnk_bl_cline
    where coalesce(cline_total_payment, 0) > 0
), labeling_1 as (
SELECT
    rbc.*,
    pbc.cus_bl_paid_order,
    (rbc.cus_cline_order = 1) as is_main_service,
    (rbc.crm_cline_order = 1) as is_main_service_bk,
    (case
        when prev_pbc.cline_payment_date is null then false
        else rbc.cline_payment_date > prev_pbc.cline_payment_date + interval '6 months'
    end) as is_line_over_6_months_in_bl,
    first_value(rbc.business_line) over (partition by rbc.code_customer order by rbc.cline_created_date, rbc.cline_id) as main_bl_customer,
    first_value(rbc.business_line) over (partition by rbc.crm_id order by rbc.cline_created_date, rbc.cline_id) as main_bl_bk
FROM rnk_bl_cline rbc
    left join paid_bl_cline pbc on pbc.cline_id = rbc.cline_id
    left join paid_bl_cline prev_pbc
        on prev_pbc.cus_bl_paid_order = pbc.cus_bl_paid_order - 1
        and prev_pbc.code_customer = pbc.code_customer
        and prev_pbc.business_line = pbc.business_line
), customer_main_bl as (
    SELECT DISTINCT code_customer, main_bl_customer
    FROM labeling_1

), main_bl_walkin as (
    -- Ngày hoàn thành (service_date_start) của phiếu khám (walkin) đầu tiên thuộc dịch vụ có
    -- business line = business line chính (main_bl_customer) của khách hàng, gán chung cho toàn
    -- bộ code_customer đó.
    -- Liên hệ: sh_medical_appointment_register_walkin (phiếu khám) <- sh_walkin_service_rel
    -- (walkin_id, service_id) -> service_id = view_stag_products.service_id (view_stag_products có
    -- CẢ product_id lẫn service_id, là 2 cột khác nhau -> phải nối đúng service_id, không phải
    -- product_id).
    -- Phiếu khám nối tới booking qua w.booking_id = crm_lead.id.
    -- LƯU Ý: các cột id (crm_lead.id, sh_medical_appointment_register_walkin.id, product_id...) có
    -- thể trùng giữa nhiều brand_etl khác nhau -> mọi join đều phải kèm điều kiện brand_etl khớp
    -- đúng cặp bảng (không chỉ join theo id) để tránh dính chéo dữ liệu giữa các brand.
    SELECT
        cl.code_customer,
        MIN(w.service_date_start) as main_bl_completed_date
    FROM customer_main_bl cmb
        INNER JOIN {{ source('crm_base', 'crm_lead') }} cl
            ON cl.code_customer = cmb.code_customer AND cl.brand_etl = 1
        INNER JOIN {{ source('crm_base', 'sh_medical_appointment_register_walkin') }} w
            ON w.booking_id = cl.id AND w.brand_etl = cl.brand_etl
        INNER JOIN {{ source('crm_base', 'sh_walkin_service_rel') }} wsr
            ON wsr.walkin_id = w.id AND wsr.brand_etl = w.brand_etl
        INNER JOIN {{ source('crm_base', 'view_stag_products') }} sp
            ON sp.service_id = wsr.service_id AND sp.brand_etl = w.brand_etl
    WHERE w.state = 'Completed'
        AND w.service_date_start IS NOT NULL
        AND cmb.main_bl_customer = CASE
            WHEN sp.his_service_type = 'Surgery' then 'PTTM'
            WHEN sp.his_service_type IN ('Spa','Laser','Card') then 'Beauty & Spa'
            WHEN sp.his_service_type = 'Odontology' then 'Nha khoa'
            WHEN sp.his_service_type = 'wellness' then 'Wellness'
            WHEN sp.his_service_type = 'weight_loss' then 'Weight Loss'
            ELSE 'Khác'
        END
    GROUP BY cl.code_customer
)
select
    lb.*,
    mbw.main_bl_completed_date,
    case
        -- Main BL của khách hàng phải đã hoàn thành (có main_bl_completed_date) mới xét bán chéo
        when mbw.main_bl_completed_date is null then false
        -- Dịch vụ thuộc main BL của khách hàng => không phải bán chéo
        when lb.business_line = lb.main_bl_customer then false
        -- Dịch vụ thuộc BL khác main BL: tính bán chéo nếu dịch vụ đó có payment > 0, và là lần
        -- mua đầu tiên của BL đó (không cần xét khoảng cách) hoặc cách lần mua liền trước của BL
        -- đó > 6 tháng (< 6 tháng thì không tính lại là bán chéo)
        when lb.business_line != lb.main_bl_customer
            and coalesce(lb.cline_total_payment, 0) > 0
            and (lb.cus_bl_paid_order = 1 or lb.is_line_over_6_months_in_bl = true)
            then true
        else false
    end as is_cross_sale
from labeling_1 lb
    left join main_bl_walkin mbw on mbw.code_customer = lb.code_customer