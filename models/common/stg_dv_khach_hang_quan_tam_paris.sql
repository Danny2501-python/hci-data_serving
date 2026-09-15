{{
  config(
    materialized = 'ephemeral'
  )
}}

-- Bản Paris (brand_etl = 3) của stg_dv_khach_hang_quan_tam.sql (bản gốc chỉ
-- tính brand_etl = 1 - Kangnam, theo đúng quy ước "mỗi brand 1 bản riêng
-- trong common/" đã áp dụng cho stg_booking_nhom_dich_vu_chinh.sql). Logic
-- giữ nguyên y hệt bản KN, chỉ đổi brand_etl + đổi source('crm_base', ...)
-- sang source('paris', ...) cho nhất quán với cách func_report_marketing_ad_cost_pr
-- khai báo nguồn (paris/sources.yml đã có sẵn crm_lead/crm_line/stag_sources/
-- view_stag_products — cùng bảng vật lý với source('crm_base', ...)).
--
-- Lấy nhóm dịch vụ khách hàng quan tâm ĐẦU TIÊN (crm_line sớm nhất của
-- customer đó, tie-break cline_id) — KHÔNG phải nhóm dịch vụ mới nhất.

WITH cline as (
    SELECT
        cl.id as crm_id,
        cl.code_customer,
        cln.brand_etl,
        cln.id as cline_id,
        cln.stage, ss.source as source, ss.category_source_code,
        CASE
            WHEN cl.customer_come = 'yes' then cl.arrival_date + interval '7 hours'
            else cl.booking_date + interval '7 hours'
        END as booking_report_date,
        cln.create_date + interval '7 hours' as cline_created_date,
        sp.product_group
    FROM {{ source('paris', 'crm_line') }} cln
        left join {{ source('paris', 'crm_lead') }} cl on cl.id = cln.crm_id and cl.brand_etl = cln.brand_etl
        left join {{ source('paris', 'stag_sources')}} ss on ss.old_id = cl.source_id and ss.brand_id = cl.brand_etl
        left join {{ source('paris', 'view_stag_products') }} sp on sp.product_id = cln.product_id and sp.brand_etl = cln.brand_etl
    WHERE cln.brand_etl = 3
), cline_rank as (
-- Cùng gotcha tie-break đã ghi ở bản KN (common/knowledge.md mục 3): nhiều
-- cline cùng booking có thể có cline_created_date giống hệt nhau (insert
-- cùng batch) -> thêm cline_id làm tiêu chí phụ.
SELECT cl.*, ROW_NUMBER() OVER (PARTITION BY cl.crm_id ORDER BY cl.cline_created_date, cl.cline_id) as cus_bk_line_order
FROM cline cl
)
SELECT
    cr.crm_id,
    cr.code_customer,
    cr.source, cr.category_source_code,
    cr.brand_etl,
    cr.booking_report_date,
    cr.product_group as first_product_group
from cline_rank cr
where cr.cus_bk_line_order = 1
