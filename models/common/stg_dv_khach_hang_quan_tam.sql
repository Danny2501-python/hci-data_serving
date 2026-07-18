{{
  config(
    materialized = 'ephemeral'
  )
}}

WITH cline as (
    SELECT 
        cl.id as crm_id,
        cl.code_customer,
        cln.brand_etl,
        cln.id as cline_id,
        cln.stage,ss.source as source,ss.category_source_code,
        CASE 
            WHEN cl.customer_come = 'yes' then cl.arrival_date + interval '7 hours'
            else cl.booking_date + interval '7 hours'
        END as booking_report_date,
        cln.create_date + interval '7 hours' as cline_created_date,
        CASE
            WHEN sp.his_service_type IN ('Spa','Laser','Card') or ss.category_source_code = 'MBS' then '8.BEAUTY & SPA'
            WHEN sp.his_service_type = 'Odontology' or UPPER(sp.product_category) ilike '%HÀM MẶT%' then '3.HÀM MẶT/NHA KHOA'
            WHEN sp.his_service_type = 'wellness' then '9.WELLNESS'
            WHEN sp.his_service_type = 'weight_loss' 
                or (sp.his_service_type = 'Surgery' and UPPER(sp.product_category) ilike '%HÚT MỠ%') then '7.BÉO ĐA CHUYÊN KHOA'
            WHEN sp.his_service_type = 'Surgery' and UPPER(sp.product_category) ilike '%MẮT%' then '1.MẮT'
            WHEN sp.his_service_type = 'Surgery' and UPPER(sp.product_category) ilike '%MŨI%' then '2.MŨI'
            WHEN sp.his_service_type = 'Surgery' and UPPER(sp.product_category) ilike '%CẤY MỠ%' then '5.CẤY MỠ'
            WHEN sp.his_service_type = 'Surgery' 
                and (UPPER(sp.product_category) ilike '%NGỰC%' or UPPER(sp.product_category) ilike '%MÔNG%') then '4.NGỰC/MÔNG'
            ELSE '6.DỊCH VỤ KHÁC'
        END as product_group
    FROM {{ source('crm_base', 'crm_line') }} cln
        left join {{ source('crm_base', 'crm_lead') }} cl on cl.id = cln.crm_id and cl.brand_etl = cln.brand_etl
        left join {{ source('crm_base', 'stag_sources')}} ss on ss.old_id = cl.source_id and ss.brand_id = cl.brand_etl
        left join {{ source('crm_base', 'stag_payment_transfer') }} spt on spt.clineid = cln.id and spt.brand_etl = cln.brand_etl
        left join {{ source('crm_base', 'view_stag_products') }} sp on sp.product_id = cln.product_id and sp.brand_etl = cln.brand_etl
),cline_rank as (
SELECT cl.*,ROW_NUMBER() OVER (PARTITION BY cl.crm_id ORDER BY cl.cline_created_date) as cus_bk_line_order
FROM cline cl
)
SELECT 
    cr.crm_id,
    cr.code_customer,
    cr.source,cr.category_source_code,
    cr.brand_etl,
    cr.booking_report_date,
    cr.product_group as first_product_group
from cline_rank cr
where cr.cus_bk_line_order = 1