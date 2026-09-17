{{
  config(
    materialized = 'view'
  )
}}

-- =============================================================================
-- stg_common_tongquan_khachhang_sm_pr
-- Bảng tổng quan khách hàng thương hiệu Paris (brand_etl = 3), tương đương
-- stg_common_tongquan_khachhang (Kangnam, brand_etl = 1) nhưng dành cho Paris.
-- Chuyển nguyên logic từ view vật lý public.view_stag_tongquan_khachhang_sm_pr
-- (đọc information_schema.views trên DB new_product ngày 2026-08-12) sang dbt.
--
-- Gộp 2 nhánh (UNION ALL), khác nhau ở bảng dòng dịch vụ và điều kiện product_category:
--   a: dòng dịch vụ (crm_line)          — product_category <> 'SAN PHAM'
--   b: dòng sản phẩm (crm_line_product) — product_category =  'SAN PHAM'
-- Booking không match được sản phẩm nào (sp.product_category NULL) bị loại khỏi
-- CẢ 2 nhánh — giữ nguyên hành vi gốc của view, không phải lỗi.
--
-- Lược bỏ so với view gốc: JOIN crm_type (ect) — không có cột nào của ect được
-- SELECT ra trong view gốc, LEFT JOIN 1-1 theo id nên không ảnh hưởng kết quả.
--
-- Thêm so với view gốc (2026-08-13, theo yêu cầu, không có trong
-- view_stag_tongquan_khachhang_sm_pr gốc):
--   phan_loai_dv — 'Dịch vụ chính' nếu nhom_dv thuộc 8 nhóm CẤY GHÉP IMPLANT / NIỀNG RĂNG
--     KHAY TRONG / NIỀNG RĂNG KHAY TRONG 0,5 / NIỀNG RĂNG MẮC CÀI KHÁC / NIỀNG RĂNG MẮC CÀI
--     KIM LOẠI THƯỜNG 0,5 / NIỀNG RĂNG MẮC CÀI KIM LOẠI TỰ BUỘC 3M / PTTM HÀM MẶT / RĂNG SỨ,
--     còn lại (kể cả NULL) → 'Dịch vụ dẫn'.
--   dv_trong_tam — tính theo cả booking (id): booking có >= 1 dòng phan_loai_dv = 'Dịch vụ
--     chính' (bất kể nhánh a/b) → mọi dòng của booking đó = 'DV trọng tâm'; booking toàn
--     'Dịch vụ dẫn' → mọi dòng = 'DV phụ'.
--   nhom_dv_dc — [Sửa 2026-08-13: đổi từ tính theo DÒNG sang tính theo BOOKING] để tính số
--     đến cửa: theo TOÀN BỘ booking (id), ưu tiên cố định — booking có bất kỳ dòng nào thuộc
--     nhóm 'Niềng răng' (5 giá trị NIỀNG RĂNG KHAY TRONG / KHAY TRONG 0,5 / MẮC CÀI KHÁC /
--     MẮC CÀI KIM LOẠI THƯỜNG 0,5 / MẮC CÀI KIM LOẠI TỰ BUỘC 3M — bỏ 'NIỀNG RĂNG' không hậu
--     tố theo yêu cầu vì không khớp giá trị nào trong dữ liệu thật) → cả booking = 'Niềng
--     răng' (ưu tiên cao nhất); nếu không có Niềng răng nhưng có 'CẤY GHÉP IMPLANT' → 'Implant';
--     rồi đến 'RĂNG SỨ' → 'Răng sứ'; rồi 'PTTM HÀM MẶT' → 'Hàm mặt'; không rơi vào 4 nhóm trên
--     → 'DV còn lại'.
--   note — (2026-08-14) lấy thẳng crm_lead.note, view gốc không SELECT cột này ra.
--   company — (2026-08-14) m_res_company.name, LEFT JOIN theo stag_payment_transfer.company_id
--     (KHÁC chinhanh — join theo ecl.company_id/crm_lead). Cả 2 vế join đều brand_etl = 3
--     (dùng lại CTE mrc3 đã filter sẵn, alias mrc_spt cho lần join thứ 2 này).
-- =============================================================================

WITH ecl AS (
    SELECT * FROM {{ source('crm_base', 'crm_lead') }}
    WHERE brand_etl = 3
        AND DATE(create_date + '07:00:00'::interval) >= '2022-01-01'
        AND active = true
),
mrc3 AS (
    SELECT * FROM {{ source('crm_base', 'm_res_company') }} WHERE brand_etl = 3
),
se AS (
    SELECT * FROM {{ ref('view_stag_employees_user') }} WHERE brand_etl = 3
),
ecs AS (
    SELECT * FROM {{ source('crm_base', 'crm_stage') }} WHERE brand_etl = 3
),
rcs AS (
    SELECT * FROM {{ source('crm_base', 'res_country_state') }} WHERE brand_etl = 3
),
ss AS (
    SELECT * FROM {{ source('crm_base', 'stag_sources') }}
),
spt AS (
    -- 1 clineid có thể có nhiều dòng payment; view gốc join thẳng không dedupe
    -- (giữ nguyên hành vi gốc — không GROUP BY ở đây để khớp 100% view).
    SELECT * FROM {{ ref('stag_payment_transfer') }}
    WHERE brand_id = 3 AND payment_date >= '2025-08-01'
),
cline AS (
    SELECT * FROM {{ source('crm_base', 'crm_line') }} WHERE brand_etl = 3
),
cline_product AS (
    SELECT * FROM {{ source('crm_base', 'crm_line_product') }} WHERE brand_etl = 3
),
us AS (
    SELECT * FROM {{ source('paris', 'utm_source') }} WHERE brand_id = 3
),
cat AS (
    SELECT * FROM {{ source('paris', 'crm_category_source') }} WHERE brand_etl = 3
),
a AS (
    SELECT
        ROW_NUMBER() OVER (PARTITION BY ecl.id ORDER BY ecl2.id) AS thu_tu,
        ecl.type_data_partner AS kh_cu_moi,
        ecl.overseas_vietnamese AS vk,
        ecl.contact_name AS ten_khach,
        ecl2.id AS line_id,
        ecl.id,
        ecl.code_customer AS ma_kh,
        ecl.phone AS sdt,
        DATE(ecl.arrival_date) AS ngay_den_cua,
        ecl.type_crm_id AS loai_ban_ghi,
        DATE(ecl.create_date + '07:00:00'::interval) AS ngay_tao,
        DATE(ecl.arrival_date + '07:00:00'::interval) AS ngay_dc,
        DATE(ecl.booking_date + '07:00:00'::interval) AS ngay_hl,
        spt.payment_date AS ngay_tt,
        CASE
            WHEN ecl.arrival_date IS NOT NULL THEN ecl.arrival_date::date
            WHEN ecl.arrival_date IS NULL THEN ecl.create_date::date
            ELSE NULL
        END AS date_time,
        ecl."name" AS ma_booking,
        se.employee AS nhan_vien,
        se.work_email,
        spt.payment AS doanh_so,
        ecl2.total_received AS tong_tien,
        CASE
            WHEN spt.payment_method IS NOT NULL THEN 'posted'
            ELSE spt.payment_method
        END AS vao_so,
        ecs."name" AS trang_thai,
        sp.product_category AS nhom_dv,
        CASE
            WHEN sp.product_category IN (
                'CẤY GHÉP IMPLANT',
                'NIỀNG RĂNG KHAY TRONG',
                'NIỀNG RĂNG KHAY TRONG 0,5',
                'NIỀNG RĂNG MẮC CÀI KHÁC',
                'NIỀNG RĂNG MẮC CÀI KIM LOẠI THƯỜNG 0,5',
                'NIỀNG RĂNG MẮC CÀI KIM LOẠI TỰ BUỘC 3M',
                'PTTM HÀM MẶT',
                'RĂNG SỨ'
            ) THEN 'Dịch vụ chính'
            ELSE 'Dịch vụ dẫn'
        END AS phan_loai_dv,
        sp.product AS ten_dv,
        CASE
            WHEN se.department = 'Sales & Marketing Thương hiệu Paris' AND ecl.create_by_department IS NULL
                THEN 'Sales & Marketing Thương hiệu Paris'
            WHEN ecl.create_by_department = 'Sales & Marketing Thương hiệu Paris'
                THEN 'Sales & Marketing Thương hiệu Paris'
            ELSE ecl.create_by_department
        END AS phong_ban_nguoi_tao1,
        ecl.create_by_department AS phong_ban_nguoi_tao,
        ss.org_source AS nguon_moi,
        ss.newcat_source AS nhom_nguon_moi,
        ecl.source_id AS nguon_bk_id,
        sp.default_code AS id_dv,
        ecl2.product_id,
        ecl.company_id AS chinhanhphanquyen,
        mrc3."name" AS chinhanh,
        mrc_spt."name" AS company,
        rcs."name" AS tinh,
        ecl.ticket_id,
        ecl.note,
        sp.his_service_type,
        sp.surgery_type,
        ecl.active,
        us.name AS source_new,
        cat.name AS ctg_source_new
    FROM ecl
    LEFT JOIN mrc3 ON mrc3.id = ecl.company_id
    LEFT JOIN cline ecl2 ON ecl2.crm_id = ecl.id
    LEFT JOIN {{ ref('view_stag_products') }} sp
        ON sp.product_id = ecl2.product_id AND ecl2.brand_etl = sp.brand_etl
    LEFT JOIN spt ON spt.clineid = ecl2.id AND spt.crm_id = ecl.id AND spt.product_id = sp.product_id
    LEFT JOIN mrc3 mrc_spt ON mrc_spt.id = spt.company_id
    LEFT JOIN se ON se.user_id = ecl.create_uid AND ecl.brand_etl = se.brand_etl
    LEFT JOIN ecs ON ecs.id = ecl.stage_id
    LEFT JOIN ss ON ss.old_id = ecl.source_id::double precision
    LEFT JOIN rcs ON ecl.state_id = rcs.id
    LEFT JOIN us ON us.id = ecl.new_source_id
    LEFT JOIN cat ON cat.id = us.category_id
    WHERE sp.product_category <> 'SAN PHAM' AND sp.product_category IS NOT NULL
),
b AS (
    SELECT
        ROW_NUMBER() OVER (PARTITION BY ecl.id ORDER BY ecl2.id) AS thu_tu,
        ecl.type_data_partner AS kh_cu_moi,
        ecl.overseas_vietnamese AS vk,
        ecl.contact_name AS ten_khach,
        ecl2.id AS line_id,
        ecl.id,
        ecl.code_customer AS ma_kh,
        ecl.phone AS sdt,
        DATE(ecl.arrival_date) AS ngay_den_cua,
        ecl.type_crm_id AS loai_ban_ghi,
        DATE(ecl.create_date + '07:00:00'::interval) AS ngay_tao,
        DATE(ecl.arrival_date + '07:00:00'::interval) AS ngay_dc,
        DATE(ecl.booking_date + '07:00:00'::interval) AS ngay_hl,
        spt.payment_date AS ngay_tt,
        CASE
            WHEN ecl.arrival_date IS NOT NULL THEN ecl.arrival_date::date
            WHEN ecl.arrival_date IS NULL THEN ecl.create_date::date
            ELSE NULL
        END AS date_time,
        ecl."name" AS ma_booking,
        se.employee AS nhan_vien,
        se.work_email,
        spt.payment AS doanh_so,
        ecl2.total_received AS tong_tien,
        CASE
            WHEN spt.payment_method IS NOT NULL THEN 'posted'
            ELSE spt.payment_method
        END AS vao_so,
        ecs."name" AS trang_thai,
        sp.product_category AS nhom_dv,
        CASE
            WHEN sp.product_category IN (
                'CẤY GHÉP IMPLANT',
                'NIỀNG RĂNG KHAY TRONG',
                'NIỀNG RĂNG KHAY TRONG 0,5',
                'NIỀNG RĂNG MẮC CÀI KHÁC',
                'NIỀNG RĂNG MẮC CÀI KIM LOẠI THƯỜNG 0,5',
                'NIỀNG RĂNG MẮC CÀI KIM LOẠI TỰ BUỘC 3M',
                'PTTM HÀM MẶT',
                'RĂNG SỨ'
            ) THEN 'Dịch vụ chính'
            ELSE 'Dịch vụ dẫn'
        END AS phan_loai_dv,
        sp.product AS ten_dv,
        CASE
            WHEN se.department = 'Sales & Marketing Thương hiệu Paris' AND ecl.create_by_department IS NULL
                THEN 'Sales & Marketing Thương hiệu Paris'
            WHEN ecl.create_by_department = 'Sales & Marketing Thương hiệu Paris'
                THEN 'Sales & Marketing Thương hiệu Paris'
            ELSE ecl.create_by_department
        END AS phong_ban_nguoi_tao1,
        ecl.create_by_department AS phong_ban_nguoi_tao,
        ss.org_source AS nguon_moi,
        ss.newcat_source AS nhom_nguon_moi,
        ecl.source_id AS nguon_bk_id,
        sp.default_code AS id_dv,
        ecl2.product_id,
        ecl.company_id AS chinhanhphanquyen,
        mrc3."name" AS chinhanh,
        mrc_spt."name" AS company,
        rcs."name" AS tinh,
        ecl.ticket_id,
        ecl.note,
        sp.his_service_type,
        sp.surgery_type,
        ecl.active,
        us.name AS source_new,
        cat.name AS ctg_source_new
    FROM ecl
    LEFT JOIN mrc3 ON mrc3.id = ecl.company_id
    LEFT JOIN cline_product ecl2 ON ecl2.booking_id = ecl.id
    LEFT JOIN {{ ref('view_stag_products') }} sp
        ON sp.product_id = ecl2.product_id AND ecl2.brand_etl = sp.brand_etl
    LEFT JOIN spt ON spt.clineid = ecl2.id AND spt.crm_id = ecl.id AND spt.product_id = sp.product_id
    LEFT JOIN mrc3 mrc_spt ON mrc_spt.id = spt.company_id
    LEFT JOIN se ON se.user_id = ecl.create_uid AND ecl.brand_etl = se.brand_etl
    LEFT JOIN ecs ON ecs.id = ecl.stage_id
    LEFT JOIN ss ON ss.old_id = ecl.source_id::double precision
    LEFT JOIN rcs ON ecl.state_id = rcs.id
    LEFT JOIN us ON us.id = ecl.new_source_id
    LEFT JOIN cat ON cat.id = us.category_id
    WHERE sp.product_category = 'SAN PHAM' AND sp.product_category IS NOT NULL
),
unioned AS (
    SELECT
        thu_tu, kh_cu_moi, vk, ten_khach, line_id, id, ma_kh, sdt, ngay_den_cua,
        loai_ban_ghi, ngay_tao, ngay_dc, ngay_hl, ngay_tt, date_time, ma_booking,
        nhan_vien, work_email, doanh_so, tong_tien, vao_so, trang_thai, nhom_dv,
        phan_loai_dv, ten_dv, phong_ban_nguoi_tao, phong_ban_nguoi_tao1, nguon_moi, nhom_nguon_moi,
        nguon_bk_id, id_dv, product_id, chinhanhphanquyen, chinhanh, company, tinh, ticket_id, note,
        his_service_type, surgery_type, active, source_new, ctg_source_new
    FROM a
    UNION ALL
    SELECT
        thu_tu, kh_cu_moi, vk, ten_khach, line_id, id, ma_kh, sdt, ngay_den_cua,
        loai_ban_ghi, ngay_tao, ngay_dc, ngay_hl, ngay_tt, date_time, ma_booking,
        nhan_vien, work_email, doanh_so, tong_tien, vao_so, trang_thai, nhom_dv,
        phan_loai_dv, ten_dv, phong_ban_nguoi_tao, phong_ban_nguoi_tao1, nguon_moi, nhom_nguon_moi,
        nguon_bk_id, id_dv, product_id, chinhanhphanquyen, chinhanh, company, tinh, ticket_id, note,
        his_service_type, surgery_type, active, source_new, ctg_source_new
    FROM b
)
-- dv_trong_tam: tính theo TOÀN BỘ booking (id) sau khi đã gộp cả 2 nhánh a/b (1 booking có
-- thể vừa có dòng dịch vụ vừa có dòng sản phẩm) — chỉ cần booking có >= 1 dòng 'Dịch vụ chính'
-- (bất kể ở nhánh nào) là cả booking được gắn 'DV trọng tâm'; booking không có dòng nào
-- 'Dịch vụ chính' (toàn 'Dịch vụ dẫn') thì gắn 'DV phụ'.
--
-- nhom_dv_dc: cũng tính theo TOÀN BỘ booking (id), theo thứ tự ƯU TIÊN cố định — nếu booking
-- xuất hiện bất kỳ dòng Niềng răng nào thì cả booking = 'Niềng răng' (ưu tiên cao nhất, bất kể
-- còn dịch vụ nào khác); nếu không có Niềng răng nhưng có Implant thì = 'Implant'; tương tự
-- Răng sứ rồi Hàm mặt; nếu không rơi vào 4 nhóm trên thì = 'DV còn lại'. Có thứ tự khác dv_trong_tam
-- (đó là boolean 2 nhánh, cái này 5 nhánh có ưu tiên) nên tách riêng, không dùng chung 1 CASE.
SELECT
    u.*,
    CASE
        WHEN bool_or(u.phan_loai_dv = 'Dịch vụ chính') OVER (PARTITION BY u.id)
            THEN 'DV trọng tâm'
        ELSE 'DV phụ'
    END AS dv_trong_tam,
    CASE
        WHEN bool_or(u.nhom_dv IN (
            'NIỀNG RĂNG KHAY TRONG',
            'NIỀNG RĂNG KHAY TRONG 0,5',
            'NIỀNG RĂNG MẮC CÀI KHÁC',
            'NIỀNG RĂNG MẮC CÀI KIM LOẠI THƯỜNG 0,5',
            'NIỀNG RĂNG MẮC CÀI KIM LOẠI TỰ BUỘC 3M'
        )) OVER (PARTITION BY u.id) THEN 'Niềng răng'
        WHEN bool_or(u.nhom_dv = 'CẤY GHÉP IMPLANT') OVER (PARTITION BY u.id) THEN 'Implant'
        WHEN bool_or(u.nhom_dv = 'RĂNG SỨ') OVER (PARTITION BY u.id) THEN 'Răng sứ'
        WHEN bool_or(u.nhom_dv = 'PTTM HÀM MẶT') OVER (PARTITION BY u.id) THEN 'Hàm mặt'
        ELSE 'DV còn lại'
    END AS nhom_dv_dc
FROM unioned u
