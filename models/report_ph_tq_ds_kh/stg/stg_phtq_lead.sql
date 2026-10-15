{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_phtq_lead — 1 dòng / lead ERP PH, đã gắn nguồn / kênh / nhân viên / trạng thái dữ liệu.
-- Ngày cộng 8 giờ (Manila). Lọc giống stg_frmacph_crm_base: create_by <> 0, type 1/2, bỏ
-- booking bảo hành. Chỉ giữ dữ liệu THAT (stg_frmacph_trang_thai).
-- Map nguồn (thay stag_sources của KN):
--   source / category_source   = utm_source.name ('MD - Facebook') / crm_category_source.name
--   channel / channel_id       = nguồn mới (new_source_id: 'Facebook', 'Hotline'...)
--   category_channel           = nhóm nguồn ('Marketing Digital'...; 'Others' → 'Nguồn khác')
-- =============================================================================
SELECT
    l.id                                                    AS lead_id,
    l.type_crm_id                                           AS loai_ban_ghi,
    l.overseas_vietnamese                                   AS viet_kieu,
    l.contact_name                                          AS ten_khach,
    l.code_customer                                         AS ma_kh,
    l.phone                                                 AS sdt,
    l.name                                                  AS ma_booking,
    l.amount_paid,
    l.type,
    l.type_data_partner,
    l.create_by_department,
    l.company_id,
    l.source_id,
    (l.create_on    + interval '8 hours')::date             AS ngay_tao,
    (l.arrival_date + interval '8 hours')::date             AS ngay_den_cua,
    (l.booking_date + interval '8 hours')::date             AS ngay_hl,
    co.name                                                 AS chi_nhanh,
    -- ERP PH đổi tên 4 trạng thái sang tiếng Anh (cùng id với ERP Kangnam) -> trả về tên Kangnam
    -- để các công thức Tableau ('Đặt lịch', 'Tham khảo'...) tính giống báo cáo KN.
    CASE st.id WHEN 5  THEN 'Chưa xử lý'
               WHEN 7  THEN 'Tham khảo'
               WHEN 18 THEN 'Đặt lịch'
               WHEN 34 THEN 'Khách không đến'
               ELSE st.name END                             AS trang_thai,
    ct.name                                                 AS loai_bk,
    uc.name                                                 AS ten_cd,
    rp.name                                                 AS nhan_vien,
    us.name                                                 AS nguon,
    cs.name                                                 AS nhom_nguon,
    usn.name                                                AS kenh,
    l.new_source_id                                         AS ma_kenh,
    CASE WHEN cs.name IN ('Others', 'Khác') THEN 'Nguồn khác' ELSE cs.name END AS nhom_kenh
FROM {{ source('ph', 'crm_lead') }} l
JOIN {{ ref('stg_frmacph_trang_thai') }} tt              ON tt.lead_id = l.id
                                                        AND tt.trang_thai_du_lieu = 'THAT'
LEFT JOIN {{ source('ph', 'm_res_company') }}       co  ON co.id  = l.company_id
LEFT JOIN {{ source('ph', 'crm_stage') }}           st  ON st.id  = l.stage_id
LEFT JOIN {{ source('ph', 'crm_type') }}            ct  ON ct.id  = l.type_crm_id
LEFT JOIN {{ source('ph', 'utm_campaign') }}        uc  ON uc.id  = l.campaign_id
LEFT JOIN {{ source('ph', 'res_users') }}           ru  ON ru.id  = l.create_by
LEFT JOIN {{ source('ph', 'res_partner') }}         rp  ON rp.id  = ru.partner_id
LEFT JOIN {{ source('ph', 'utm_source') }}          us  ON us.id  = l.source_id
LEFT JOIN {{ source('ph', 'crm_category_source') }} cs  ON cs.id  = l.category_source_id
LEFT JOIN {{ source('ph', 'utm_source') }}          usn ON usn.id = l.new_source_id
WHERE coalesce(l.create_by, 0) <> 0
  AND l.type_crm_id IN (1, 2)
  AND (l.reason_cancel_booking IS NULL OR l.reason_cancel_booking <> 'tao_booking_bh')
