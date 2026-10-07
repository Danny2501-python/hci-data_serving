{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_trang_thai — phân loại lead ERP PH: TEST / NGHI_TEST / THAT
-- Ưu tiên: ghi đè thủ công (sandbox_ph.danh_dau_thu_cong) > tài khoản test
-- (sandbox_ph.tk_test) > từ khoá test > booking không có mã 'BOOK-' > nghi test
-- (VP thương hiệu / quốc gia VN) > thật.
-- [2026-10-07] Thêm quy tắc: booking (type_crm_id = 2) thật luôn có mã crm_lead.name
-- dạng 'BOOK-yymmdd-xxxxx' (xác nhận với user). Không áp cho lead (type 1 – name là tên
-- khách) và booking bảo hành (type 3 – mã 'BH-').
-- Cùng quy tắc với view sandbox_ph.v_lead_trang_thai.
-- =============================================================================
SELECT
    l.id AS lead_id,
    CASE
        WHEN m.lead_id IS NOT NULL                       THEN m.trang_thai
        WHEN t.user_id IS NOT NULL                       THEN 'TEST'
        WHEN lower(concat_ws(' ', l.name, l.contact_name, l.description, l.street))
             ~ '(test|aaaa|demo|asdf|thử nghiệm|thu nghiem)' THEN 'TEST'
        WHEN l.type_crm_id = 2
         AND coalesce(l.name, '') NOT ILIKE 'BOOK-%'     THEN 'TEST'
        WHEN l.company_id = 54                           THEN 'NGHI_TEST'
        WHEN l.country_id = 241                          THEN 'NGHI_TEST'
        ELSE 'THAT'
    END AS trang_thai_du_lieu,
    CASE
        WHEN m.lead_id IS NOT NULL                       THEN 'Ghi đè thủ công: ' || coalesce(m.ghi_chu, '')
        WHEN t.user_id IS NOT NULL                       THEN 'Tạo bởi TK test: ' || t.login
        WHEN lower(concat_ws(' ', l.name, l.contact_name, l.description, l.street))
             ~ '(test|aaaa|demo|asdf|thử nghiệm|thu nghiem)' THEN 'Có từ khoá test'
        WHEN l.type_crm_id = 2
         AND coalesce(l.name, '') NOT ILIKE 'BOOK-%'     THEN 'Booking không có mã BOOK-'
        WHEN l.company_id = 54                          THEN 'Công ty = Văn phòng thương hiệu'
        WHEN l.country_id = 241                          THEN 'Quốc gia = Việt Nam'
        ELSE ''
    END AS ly_do
FROM {{ source('ph', 'crm_lead') }} l
LEFT JOIN {{ source('sandbox_ph', 'danh_dau_thu_cong') }} m ON m.lead_id = l.id
LEFT JOIN {{ source('sandbox_ph', 'tk_test') }}           t ON t.user_id = l.create_uid
