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
        -- [Đã điều chỉnh 2026-08-05] Trước đây tự tính CASE WHEN riêng (9 nhóm, có tiền tố số) --
        -- đổi sang lấy THẲNG sp.product_group (đã bake sẵn trong view_stag_products, dùng chung
        -- cho toàn bộ hệ thống, kể cả sandbox view_stag_crm_lead_first_product_group). Đã verify
        -- view_stag_products trên new_product và staging_sci (sandbox) giống hệt nhau 100% (kể cả
        -- đoạn CASE này) -- lấy trực tiếp từ đây đảm bảo khớp sandbox tuyệt đối, không cần tự
        -- duy trì bản sao CASE dễ trôi (drift) theo thời gian. Nhãn đổi từ "1.MẮT"/"8.BEAUTY & SPA"
        -- (tiền tố số cũ) sang đúng nhãn sp.product_group ("PTTM MẮT"/"BEAUTY & SPA"/"SẢN PHẨM"...).
        sp.product_group,
        -- Danh mục gốc (CHƯA gom nhóm qua CASE WHEN) của sp.product_group — input thô của
        -- view_stag_products, dùng cho cột "dịch vụ KH quan tâm ban đầu chưa gom nhóm".
        sp.product_category
    FROM {{ source('crm_base', 'crm_line') }} cln
        left join {{ source('crm_base', 'crm_lead') }} cl on cl.id = cln.crm_id and cl.brand_etl = cln.brand_etl
        left join {{ source('crm_base', 'stag_sources')}} ss on ss.old_id = cl.source_id and ss.brand_id = cl.brand_etl
        left join {{ source('crm_base', 'view_stag_products') }} sp on sp.product_id = cln.product_id and sp.brand_etl = cln.brand_etl
),cline_rank as (
-- [Đã điều chỉnh 2026-08-05] Thêm cline_id làm tiêu chí phụ -- nhiều cline cùng booking có thể
-- có cline_created_date GIỐNG HỆT NHAU (insert cùng batch), thiếu tie-break khiến ROW_NUMBER()
-- chọn ngẫu nhiên dòng "đầu tiên" giữa các lần chạy (xem common/knowledge.md mục 3).
SELECT cl.*,ROW_NUMBER() OVER (PARTITION BY cl.crm_id ORDER BY cl.cline_created_date, cl.cline_id) as cus_bk_line_order
FROM cline cl
)
SELECT 
    cr.crm_id,
    cr.code_customer,
    cr.source,cr.category_source_code,
    cr.brand_etl,
    cr.booking_report_date,
    cr.product_group as first_product_group,
    cr.product_category as first_product_category
from cline_rank cr
where cr.cus_bk_line_order = 1