{{
  config(
    materialized = 'ephemeral'
  )
}}

-- =============================================================================
-- stg_common_tongquan_khachhang_da — bản ĐÔNG Á (brand_etl = 2) của
-- stg_common_tongquan_khachhang (bản gốc chỉ tính Kangnam, brand_etl = 1).
-- Giữ nguyên tên cột ra và cách phân loại Lead / Booking / Đến Cửa / Thành Công.
--
-- Khác bản Kangnam (đã kiểm tra trên dữ liệu thật staging_sci, 21/10/2026):
--   1. Mọi filter/join brand_etl = 1 -> 2 (crm_lead, crm_line, m_res_company,
--      res_brand, crm_stage, crm_type). type_crm_id (1 = Lead new, 2 = Booking new)
--      và tên stage (Won / Đặt cọc / Đang xử lý) của Đông Á giống hệt Kangnam.
--   2. Sản phẩm: bản Kangnam join stag_products theo product_id Kangnam; Đông Á
--      dùng view_stag_products (brand_etl = 2) — 100% crm_line Đông Á đã khớp.
--      view_stag_products không có default_code -> id_dv để NULL (không model nào dùng).
--   3. Doanh số: chỉ stag_payment_transfer brand_etl = 2 (không lấy brand 0 vì
--      crm_id không unique giữa các brand). Dữ liệu Đông Á có từ 06/09/2026.
--      Bỏ join account_payment: bản Kangnam join nhưng không lấy cột nào,
--      chỉ có nguy cơ nhân dòng.
--   4. Nguồn: stag_sources chỉ có dòng brand_id = 1, nhưng ERP Đông Á nhân bản
--      từ Kangnam nên source_id giống hệt (219 = 'K - Cho thuê phòng Mổ',
--      195 = 'MD - Facebook', ... — đã đối chiếu utm_source brand_etl 1 vs 2).
--      -> Nguồn / nhóm nguồn lấy từ stag_sources brand_id = 1 (giữ đúng bộ tên
--      và nhóm như báo cáo Kangnam); nguồn nào stag_sources không có thì lấy
--      tên / nhóm trong danh mục riêng của Đông Á (utm_source / crm_category_source
--      brand_etl = 2). LƯU Ý: utm_source phải lọc theo brand_etl, KHÔNG phải
--      brand_id (brand_id = mã thương hiệu bên trong từng ERP, = 1 ở mọi brand).
--   5. Nhân viên tạo: stag_employees.da_user_id (thay cho kn_user_id), lấy đúng
--      1 dòng để không nhân dòng nếu 1 user gắn nhiều hồ sơ nhân viên.
-- =============================================================================

WITH ecl AS (
    SELECT * FROM {{ source('crm_base', 'crm_lead') }} WHERE brand_etl = 2
),
cline AS (
    SELECT * FROM {{ source('crm_base', 'crm_line') }} WHERE brand_etl = 2
),
spt AS (
    SELECT * FROM {{ source('crm_base', 'stag_payment_transfer') }} WHERE brand_etl = 2
),
a AS (
    SELECT
        ROW_NUMBER() OVER (PARTITION BY ecl.id ORDER BY ecl2.id) AS thu_tu,
        ecl.reason_cancel_booking,
        ecl.type_data_partner AS kh_cu_moi,
        ecl.overseas_vietnamese AS vk,
        ecl.contact_name AS Ten_Khach,
        ecl2.id AS line_id,
        ecl.id AS id,
        ecl.code_customer AS Ma_KH,
        ecl.phone AS sdt,
        DATE(ecl.arrival_date + '07:00:00'::interval) AS Ngay_den_cua,
        ecl.type_crm_id AS Loai_ban_ghi,
        DATE(ecl.create_on + '07:00:00'::interval) AS Ngay_tao,
        DATE(ecl.arrival_date + '07:00:00'::interval) AS Ngay_dc,
        DATE(ecl.booking_date + '07:00:00'::interval) AS Ngay_hl,
        DATE(spt.payment_date + '00:00:00'::interval) AS Ngay_tt,
        CASE
            WHEN ecl.arrival_date IS NOT NULL THEN ecl.arrival_date::DATE
            ELSE ecl.create_on::DATE
        END AS Date_Time,
        ecl."name" AS Ma_Booking,
        se.employee AS Nhan_Vien,
        spt.payment AS doanh_so,
        ecl2.total_received AS Tong_tien,
        CASE WHEN spt.id IS NOT NULL THEN 'posted' ELSE 'no_money' END AS vao_so,
        ecs2.name AS Trang_Thai,
        CASE
            WHEN spt.id LIKE '%to%' THEN 'Transfer'
            WHEN spt.id LIKE '%ti%' THEN 'Recieve'
            ELSE ecl2.stage
        END AS Line_tt,
        CASE
            WHEN ecl.arrival_date IS NOT NULL AND ecs2.name IN ('Won', 'Đặt cọc', 'Đang xử lý') THEN 'Thành Công'
            WHEN ecl.arrival_date IS NOT NULL AND ecs2.name NOT IN ('Won', 'Đặt cọc', 'Đang xử lý') THEN 'Đến Cửa'
            WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '2' THEN 'Booking'
            WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '1' THEN 'Lead'
        END AS Phan_Loai_Khach,
        ect.name AS Loai_BK,
        CASE
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN erb3."name"
            ELSE erb."name"
        END AS Thuong_hieu,
        sp.product_category AS Nhom_DV,
        sp.product AS Ten_DV,
        CASE
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN mrc3."name"
            ELSE mrc."name"
        END AS Chi_Nhanh,
        CASE
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN mrc3.id
            ELSE mrc.id
        END AS chinhanhphanquyen,
        ecl.create_by_department AS Phong_ban_nguoi_tao,
        COALESCE(ss.source, uso.name) AS Nguon_moi,
        COALESCE(ss.newcat_source, cso.name) AS Nhom_nguon_moi,
        ecl.source_id AS Nguon_bk_id,
        NULL::text AS id_dv,
        spt.ma_phieu,
        CONCAT(ecl.id, ecl2.id, spt.id) AS fk,
        CAST(NULL AS FLOAT) AS tien_ap
    FROM ecl
    LEFT JOIN {{ source('crm_base', 'res_brand') }} erb3
           ON erb3.id = ecl.brand_id AND erb3.brand_etl = 2
    LEFT JOIN {{ source('crm_base', 'm_res_company') }} mrc3
           ON mrc3.id = ecl.company_id AND mrc3.brand_etl = 2
    LEFT JOIN cline ecl2
           ON ecl2.crm_id = ecl.id
    LEFT JOIN {{ source('crm_base', 'view_stag_products') }} sp
           ON sp.product_id = ecl2.product_id AND sp.brand_etl = 2
    LEFT JOIN spt
           ON spt.clineid = ecl2.id AND spt.crm_id = ecl.id
    LEFT JOIN {{ source('crm_base', 'm_res_company') }} mrc
           ON mrc.id = spt.company_id AND mrc.brand_etl = 2
    LEFT JOIN {{ source('crm_base', 'res_brand') }} erb
           ON erb.id = mrc.brand_id AND erb.brand_etl = 2
    LEFT JOIN LATERAL (
        SELECT se1.employee
        FROM {{ source('crm_base', 'stag_employees') }} se1
        WHERE se1.da_user_id = ecl.create_by
        ORDER BY se1.active DESC NULLS LAST, se1.id DESC
        LIMIT 1
    ) se ON TRUE
    LEFT JOIN {{ source('crm_base', 'crm_stage') }} ecs2
           ON ecs2.id = ecl.stage_id AND ecs2.brand_etl = 2
    LEFT JOIN {{ source('crm_base', 'crm_type') }} ect
           ON ect.id = ecl.type_crm_id AND ect.brand_etl = 2
    -- Nguồn: stag_sources brand_id = 1, dự phòng bằng danh mục riêng của Đông Á (xem mục 4)
    LEFT JOIN {{ source('crm_base', 'stag_sources') }} ss
           ON ss.old_id = ecl.source_id AND ss.brand_id = 1
    LEFT JOIN LATERAL (
        SELECT u.name, u.category_id
        FROM {{ source('kangnam', 'utm_source') }} u
        WHERE u.id = ecl.source_id AND u.brand_etl = 2
        LIMIT 1
    ) uso ON TRUE
    LEFT JOIN {{ source('kangnam', 'crm_category_source') }} cso
           ON cso.id = uso.category_id AND cso.brand_etl = 2
    WHERE DATE(ecl.create_on) >= '2024-01-01'
      AND ecl.active = true
      AND ecl.create_by <> 0
)
SELECT * FROM a
