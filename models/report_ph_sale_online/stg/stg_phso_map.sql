{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_phso_map — tương đương stg_kso_map (report_kn_sale_online) cho ERP Philippines
-- (schema ph, brand_etl = 9). Cấp dữ liệu: lead × dòng dịch vụ (giống KN).
-- Khác KN:
--   * KHÔNG lọc active = true (ERP PH để booking đến/Won/thanh toán ở active = false).
--   * Giữ cả lead KHÔNG có dòng dịch vụ (lead type 1 ở PH gần như không có crm_line;
--     KN bắt buộc có sản phẩm nên nếu áp nguyên sẽ mất toàn bộ Lead_total) → nhom_dv 'KXĐ'.
--   * Ngày: UTC + 8 giờ (Manila); KN + 7.
--   * Không join doanh số ở đây (tránh nhân dòng như KN) – DS tính riêng ở mart.
--   * Không có stag_crm_booking_arrival_company cho brand 9 → chi nhánh = company_id.
--   * work_email = ph.res_users.login (email), nối sang bảng team theo email.
--   * [2026-10-07] ma_booking của LEAD (type 1): crm_lead.name của lead là TÊN KHÁCH
--     (KN cũng vậy) → thay bằng mã booking mà lead đã chuyển thành (booking.lead_id =
--     lead.id, lấy booking tạo đầu tiên); lead chưa chuyển → NULL. Tên vẫn ở ten_khach.
-- =============================================================================
SELECT
    l.id                                                AS lead_id,
    cl.id                                               AS line_id,
    l.type_crm_id                                       AS loai_ban_ghi,
    l.overseas_vietnamese                               AS vk,
    l.contact_name                                      AS ten_khach,
    l.code_customer                                     AS ma_kh,
    l.phone                                             AS sdt,
    CASE WHEN l.type_crm_id = 1 THEN bk.name ELSE l.name END AS ma_booking,
    l.ticket_id::text                                   AS ticket_id,
    DATE(l.create_date  + interval '8 hours')           AS ngay_tao,
    DATE(l.arrival_date + interval '8 hours')           AS ngay_den_cua,
    DATE(l.booking_date + interval '8 hours')           AS ngay_hl,
    st.name                                             AS trang_thai,
    l.reason_cancel_booking,
    us.name                                             AS nguon,
    co.name                                             AS chi_nhanh,
    l.company_id                                        AS chinhanhphanquyen,
    rcs.name                                            AS tinh,
    lower(ru.login)                                     AS work_email,
    coalesce(pc.name, 'KXĐ')                            AS nhom_dv,
    pt.name                                             AS ten_dv,
    cl.his_service_type,
    NULL::text                                          AS surgery_type,
    coalesce(cl.total_received, 0)                      AS tong_tien,
    tt.trang_thai_du_lieu,
    tt.ly_do
FROM {{ source('ph', 'crm_lead') }} l
LEFT JOIN {{ source('ph', 'crm_line') }}          cl  ON cl.crm_id = l.id
LEFT JOIN {{ source('ph', 'product_product') }}   pp  ON pp.id  = cl.product_id
LEFT JOIN {{ source('ph', 'product_template') }}  pt  ON pt.id  = pp.product_tmpl_id
LEFT JOIN {{ source('ph', 'product_category') }}  pc  ON pc.id  = pt.categ_id
LEFT JOIN {{ source('ph', 'crm_stage') }}         st  ON st.id  = l.stage_id
LEFT JOIN {{ source('ph', 'utm_source') }}        us  ON us.id  = l.source_id
LEFT JOIN {{ source('ph', 'm_res_company') }}     co  ON co.id  = l.company_id
LEFT JOIN {{ source('ph', 'res_country_state') }} rcs ON rcs.id = l.state_id
LEFT JOIN {{ source('ph', 'res_users') }}         ru  ON ru.id  = l.create_uid
LEFT JOIN {{ ref('stg_frmacph_trang_thai') }}     tt  ON tt.lead_id = l.id
LEFT JOIN LATERAL (     -- booking mà lead đã chuyển thành (chỉ dùng cho lead type 1)
    SELECT b.name FROM {{ source('ph', 'crm_lead') }} b
    WHERE b.lead_id = l.id AND b.type_crm_id = 2
    ORDER BY b.id LIMIT 1
) bk ON TRUE
WHERE coalesce(pc.name, 'KXĐ') <> 'SAN PHAM'
