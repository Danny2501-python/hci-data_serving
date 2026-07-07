{{
  config(
    materialized = 'view',
    alias        = 'view_stag_crm_line_cross_sale'
  )
}}

WITH cline as (
    SELECT 
        cl.id as crm_id,
        cl.code_customer,
        cln.brand_etl,
        cln.id as cline_id,
        cln.stage,
        CASE 
            WHEN cl.customer_come = 'yes' then cl.arrival_date + interval '7 hours'
            else cl.booking_date + interval '7 hours'
        END as booking_report_date,
        cln.create_date + interval '7 hours' as cline_created_date,
        spt.payment_date as cline_payment_date,
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
        left join {{ source('crm_base', 'stag_payment_transfer') }} spt on spt.clineid = cln.id and spt.brand_etl = cln.brand_etl
        left join {{ source('crm_base', 'view_stag_products') }} sp on sp.product_id = cln.product_id and sp.brand_etl = cln.brand_etl
    WHERE cl.id in (SELECT crm_id FROM {{ ref('stg_booking_id_co_tien_tc') }})
), rnk_bl_cline as (
    select cln.*,
        ROW_NUMBER() OVER (PARTITION BY cln.business_line, cln.code_customer ORDER BY cln.cline_created_date) as cus_bl_cline_order,
        ROW_NUMBER() OVER (PARTITION BY cln.crm_id ORDER BY cln.cline_created_date) as crm_cline_order,
        ROW_NUMBER() OVER (PARTITION BY cln.code_customer ORDER BY cln.cline_created_date) as cus_cline_order
    from cline cln
    WHERE cln.brand_etl = 1 and cln.booking_report_date >= '2026-06-01'
), labeling_1 as (
SELECT 
    rbc.*,
    (rbc.cus_cline_order = 1) as is_main_service,
    (rbc.crm_cline_order = 1) as is_main_service_bk,
    (case 
        when prev_rbc.cline_payment_date is null then false
        else rbc.cline_payment_date > prev_rbc.cline_payment_date + interval '6 months'
    end) as is_line_over_6_months_in_bl,
    first_value(rbc.business_line) over (partition by rbc.code_customer order by rbc.cline_created_date) as main_bl_customer,
    first_value(rbc.business_line) over (partition by rbc.crm_id order by rbc.cline_created_date) as main_bl_bk
FROM rnk_bl_cline rbc
    left join rnk_bl_cline prev_rbc 
        on prev_rbc.cus_bl_cline_order = rbc.cus_bl_cline_order - 1
        and prev_rbc.code_customer = rbc.code_customer
        and prev_rbc.business_line = rbc.business_line
)
select 
    lb.*,
    case 
        -- nếu là BL đầu tiên khách hàng quan tâm => không bán chéo 
        when lb.is_main_service = true then false
        -- Khách hàng mua dịch vụ khác với business line đầu tiên mà họ quan tâm và là line đầu tiên của BL khác, trạng thái thành công => bán chéo
        when lb.is_main_service = false 
            and lb.cus_bl_cline_order = 1 
            and lb.business_line != lb.main_bl_customer 
            and lb.stage IN ('processing', 'done') then true
        -- Khách hàng mua dịch vụ khác với business line đầu tiên mà họ quan tâm và không phải là line đầu tiên của BL khác, trạng thái thành công và cách liền trước của BL đó > 6 tháng => bán chéo
        when lb.is_main_service = false 
            and lb.cus_bl_cline_order != 1 
            and lb.business_line != lb.main_bl_customer 
            and lb.is_line_over_6_months_in_bl = true 
            and lb.stage IN ('processing', 'done') then true
        -- Khách hàng mua dịch vụ thuộc BL đầu tiên mà họ quan tâm nhưng không phải là dòng đầu tiên của BL đó, trạng thái thành công và cách dòng đầu tiên > 6 tháng và BL khác với BL đầu tiên của booking => bán chéo
        when lb.is_main_service = false
            and lb.is_main_service_bk = false
            and lb.business_line = lb.main_bl_customer
            and lb.is_line_over_6_months_in_bl = true
            and lb.business_line != lb.main_bl_bk
            and lb.stage IN ('processing', 'done') then true
        else false
    end as is_cross_sale
from labeling_1 lb