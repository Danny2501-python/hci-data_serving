{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_crm_base — 1 dòng / lead ERP Philippines (schema ph, brand 9)
-- Tương đương stg_frmack_crm_base (KN) nhưng ở cấp lead (KN ở cấp lead × dòng DV
-- × phiếu thu); Metric = SĐT nên đếm COUNTD(Metric) cho kết quả tương đương.
-- Ngày: ERP lưu UTC → cộng 8 giờ (giờ Manila). KN dùng +7 (giờ Việt Nam).
-- Lọc: create_by <> 0, bỏ booking bảo hành (type_crm_id = 3 'Booking bảo hành',
-- reason_cancel_booking = 'tao_booking_bh').
-- KHÔNG lọc active = true như KN: ở ERP PH, booking đã đến/Won/đã thanh toán và lead
-- đã chuyển thành booking đều có active = false (xác nhận với user 2026-10-05).
-- Dữ liệu test được loại bằng cột trang_thai_du_lieu thay thế.
-- =============================================================================
WITH line AS (
    SELECT
        cl.crm_id,
        sum(cl.total_received)                                        AS tong_tien,
        -- nhóm DV / tên DV của dòng dịch vụ đầu tiên
        (array_agg(pc.name ORDER BY cl.id))[1]                        AS nhom_dv,
        (array_agg(pt.name ORDER BY cl.id))[1]                        AS ten_dv
    FROM {{ source('ph', 'crm_line') }} cl
    LEFT JOIN {{ source('ph', 'product_product') }}  pp ON pp.id = cl.product_id
    LEFT JOIN {{ source('ph', 'product_template') }} pt ON pt.id = pp.product_tmpl_id
    LEFT JOIN {{ source('ph', 'product_category') }} pc ON pc.id = pt.categ_id
    GROUP BY cl.crm_id
)
SELECT
    l.id                                                   AS lead_id,
    l.type_crm_id                                          AS loai_ban_ghi,
    l.overseas_vietnamese                                  AS vk,
    l.phone                                                AS sdt,
    DATE(l.create_on    + interval '8 hours')              AS ngay_tao,
    DATE(l.arrival_date + interval '8 hours')              AS ngay_den_cua,
    DATE(l.booking_date + interval '8 hours')              AS ngay_hl,
    coalesce(line.tong_tien, 0)                            AS tong_tien,
    coalesce(line.nhom_dv, 'KXĐ')                          AS nhom_dv,
    coalesce(line.ten_dv, 'DV')                            AS ten_dv,
    co.name                                                AS chi_nhanh,
    rc.name                                                AS quoc_gia,
    coalesce(rcs.name, 'KXĐ')                              AS local_k,
    coalesce(us.name, 'KXĐ')                               AS nguon,
    coalesce(cs.name, 'KXĐ')                               AS nhom_nguon,
    usn.name                                               AS nguon_moi_v2,
    csn.name                                               AS nhom_nguon_moi_v2,
    -- kênh: cùng quy tắc text-match nguồn như KN (stg_frmack_crm_base)
    CASE WHEN coalesce(usn.name, us.name) ILIKE '%facebook%' THEN 'FB'
         WHEN coalesce(usn.name, us.name) ILIKE '%seo%'
           OR coalesce(usn.name, us.name) ILIKE '%google%'
           OR coalesce(usn.name, us.name) ILIKE '%hotline%'  THEN 'Web'
         ELSE 'Khác'
    END                                                    AS kenh,
    nullif(l.pancake_page_id, '')                          AS page_id,
    l.reason_cancel_booking
FROM {{ source('ph', 'crm_lead') }} l
LEFT JOIN line                                              ON line.crm_id = l.id
LEFT JOIN {{ source('ph', 'm_res_company') }}       co  ON co.id  = l.company_id
LEFT JOIN {{ source('ph', 'res_country') }}         rc  ON rc.id  = l.country_id
LEFT JOIN {{ source('ph', 'res_country_state') }}   rcs ON rcs.id = l.state_id
LEFT JOIN {{ source('ph', 'utm_source') }}          us  ON us.id  = l.source_id
LEFT JOIN {{ source('ph', 'crm_category_source') }} cs  ON cs.id  = l.category_source_id
LEFT JOIN {{ source('ph', 'utm_source') }}          usn ON usn.id = l.new_source_id
LEFT JOIN {{ source('ph', 'crm_category_source') }} csn ON csn.id = usn.category_id
WHERE coalesce(l.create_by, 0) <> 0
  AND l.type_crm_id IN (1, 2)
  AND (l.reason_cancel_booking IS NULL OR l.reason_cancel_booking <> 'tao_booking_bh')
