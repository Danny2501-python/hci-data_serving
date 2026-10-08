{{
  config(
    materialized = 'ephemeral'
  )
}}

WITH cline as (
    SELECT 
        cl.id as crm_id,
        cln.brand_etl,
        cln.id as cline_id,
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
        left join {{ source('crm_base', 'view_stag_products') }} sp on sp.product_id = cln.product_id and sp.brand_etl = cln.brand_etl
    -- [SUA BUG 2026-10-08] Truoc day file nay KHONG co WHERE nao -> tinh tren toan bo
    -- crm_line cua MOI brand (1.711.031 dong) du ca 3 consumer deu chi dung brand_etl = 1.
    -- Hai hau qua:
    --   1. SAI SO: 61.408 crm_id bi trung giua cac brand (crm_lead.id KHONG unique toan cuc).
    --      ROW_NUMBER() PARTITION BY crm_id gop ca cac brand vao 1 partition -> chi 1 dong
    --      song sot, neu dong thang khong thuoc brand 1 thi join
    --      `dkq.crm_id = cl.id AND dkq.brand_etl = cl.brand_etl` o consumer bi MISS
    --      -> nhan ra 'KXD' sai. Anh huong CA func_report_marketing_ad_cost_kn.
    --   2. CHAM: sort 1.711.031 dong de lay ~138.436 dong brand 1 (~12x cong vo ich).
    -- Them WHERE nay dung theo quy uoc "moi brand 1 ban rieng trong common/" ma ban
    -- stg_dv_khach_hang_quan_tam_paris.sql (WHERE cln.brand_etl = 3) da ghi la y dinh goc.
    WHERE cln.brand_etl = 1
),cline_rank as (
-- [Đã điều chỉnh 2026-08-05] Thêm cline_id làm tiêu chí phụ -- nhiều cline cùng booking có thể
-- có cline_created_date GIỐNG HỆT NHAU (insert cùng batch), thiếu tie-break khiến ROW_NUMBER()
-- chọn ngẫu nhiên dòng "đầu tiên" giữa các lần chạy (xem common/knowledge.md mục 3).
SELECT cl.*,ROW_NUMBER() OVER (PARTITION BY cl.crm_id ORDER BY cl.cline_created_date, cl.cline_id) as cus_bk_line_order
FROM cline cl
)
-- [Toi uu 2026-10-08] Da bo 5 cot chet (code_customer, source, category_source_code,
-- booking_report_date, stage) va join stag_sources di kem -- KHONG consumer nao dung chung.
-- Ca 3 consumer (func_report_marketing_ad_cost_kn: stg_frmack_crm_base + stg_frmack_doanh_so,
-- report_kn_sale_online: stg_kso_map) chi doc dung 4 cot duoi day. Model la ephemeral nen
-- khong ton tai vat ly -> khong co query nao ngoai dbt doc duoc no.
SELECT 
    cr.crm_id,
    cr.brand_etl,
    cr.product_group as first_product_group,
    cr.product_category as first_product_category
from cline_rank cr
where cr.cus_bk_line_order = 1