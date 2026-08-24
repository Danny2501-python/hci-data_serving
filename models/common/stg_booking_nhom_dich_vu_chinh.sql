{{
  config(
    materialized = 'ephemeral'
  )
}}

-- Chỉ tính brand_etl = 1 (thương hiệu Kangnam).
--
-- [Đổi 2026-08-05] Khớp lại logic theo view_stag_crm_lead_first_product_group bên DB sandbox
-- (staging_sci @ 10.10.10.226):
--
--   SELECT DISTINCT ON (cl.id) cl.id AS crm_id, ..., sp.product_group AS first_product_group
--   FROM crm_line cln
--       LEFT JOIN crm_lead cl ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
--       LEFT JOIN view_stag_products sp ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
--   ORDER BY cl.id, cln.id
--
-- Bỏ hẳn 3 tầng ưu tiên cũ (crm_lead_product_category_rel / custom field 9794 / fallback cline
-- theo create_date) -- chuyển sang ĐÚNG 1 nguồn duy nhất giống sandbox: cline có `cln.id` NHỎ
-- NHẤT trong booking (không phải cline_created_date sớm nhất -- 2 tiêu chí có thể cho kết quả
-- khác nhau nếu id không tăng đúng theo thứ tự tạo, nhưng đây là đúng logic sandbox đang dùng).
--
-- `nhom_dich_vu_chinh` = `view_stag_products.product_group` -- nhãn ĐÃ PHÂN NHÓM SẴN (không phải
-- category thô như bản trước), lấy trực tiếp từ CASE WHEN đã bake sẵn trong view_stag_products:
--   SẢN PHẨM / BEAUTY & SPA / PTTM HÀM MẶT / WELLNESS / BÉO ĐA CHUYÊN KHOA / PTTM MẮT / PTTM MŨI /
--   CẤY MỠ / PTTM NGỰC/MÔNG / DỊCH VỤ KHÁC
-- (đã verify: view_stag_products trên new_product và staging_sci (sandbox) giống hệt nhau 100%,
-- kể cả đoạn CASE này).
--
-- `his_service_type`/`business_line` giờ lấy TRỰC TIẾP từ đúng dòng view_stag_products đã join
-- (không cần join phụ sang stag_products_dbt theo product_ctg_id/mode như bản trước -- vì giờ chỉ
-- có 1 nguồn duy nhất, không còn tình huống 1 category ứng với nhiều his_service_type khác nhau
-- cần chọn mode).
--
-- Phạm vi `brand_etl = 1`: sandbox view không filter brand (tính cho mọi brand), nhưng model này
-- vẫn giữ filter `brand_etl = 1` theo đúng quy ước chung của các model trong `common/` (chỉ tính
-- Kangnam) -- không phải sai lệch logic, chỉ là thu hẹp phạm vi tính toán.

SELECT DISTINCT ON (cl.id)
    cl.id AS crm_id,
    cln.brand_etl,
    sp.product_group AS nhom_dich_vu_chinh,
    sp.product_ctg_id AS product_category_id,
    sp.his_service_type,
    CASE
        WHEN sp.his_service_type = 'Surgery' then 'PTTM'
        WHEN sp.his_service_type IN ('Spa','Laser','Card') then 'Beauty & Spa'
        WHEN sp.his_service_type = 'Odontology' then 'Nha khoa'
        WHEN sp.his_service_type = 'wellness' then 'Wellness'
        WHEN sp.his_service_type = 'weight_loss' then 'Weight Loss'
        WHEN sp.his_service_type IS NOT NULL then 'Khác'
        ELSE NULL
    END as business_line
FROM {{ source('crm_base', 'crm_line') }} cln
    LEFT JOIN {{ source('crm_base', 'crm_lead') }} cl ON cl.id = cln.crm_id AND cl.brand_etl = cln.brand_etl
    LEFT JOIN {{ source('crm_base', 'view_stag_products') }} sp ON sp.product_id = cln.product_id AND sp.brand_etl = cln.brand_etl
WHERE cln.brand_etl = 1
ORDER BY cl.id, cln.id
