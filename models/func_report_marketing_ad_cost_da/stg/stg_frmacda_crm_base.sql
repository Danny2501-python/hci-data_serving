{{
  config(
    materialized = 'ephemeral'
  )
}}

-- =============================================================================
-- stg_frmacda_crm_base — bản ĐÔNG Á của stg_frmack_crm_base (Kangnam).
-- Bảng khách hàng gốc (CRM) dùng chung cho DC / Lead / TC / BKHL / HL.
--
-- Khác bản Kangnam:
--   1. Nguồn dữ liệu: stg_common_tongquan_khachhang_da, crm_lead brand_etl = 2.
--   2. Chưa có CareSoft Đông Á -> không join cs_ticket_* : ad_id = NULL,
--      kenh chỉ suy ra từ tên nguồn. Thêm lại khi kéo được CareSoft Đông Á.
--   3. 'MD - Search' (Google Ads Search) -> 'Web' trực tiếp từ tên nguồn
--      (bản Kangnam cần ticket CareSoft mới phân được, xem README Kangnam mục 20).
--   4. Tỉnh / quốc gia: ưu tiên res_country_state / res_country brand 2, nếu
--      không có thì lấy brand 1 (ERP Đông Á nhân bản từ ERP Kangnam nên id trùng).
--   5. nguon_moi_v2: Đông Á hiện không có new_source_id -> suy từ source_id qua
--      m_utm_source_old_new_map, ưu tiên mapping của Đông Á (brand_etl = 2) nếu
--      có, không có thì dùng mapping Kangnam (brand_etl = 1) vì source_id giống
--      hệt. utm_source lọc theo brand_etl (KHÔNG phải brand_id).
--   6. Không có remap chi nhánh kiểu Kangnam (Bạch Mai / Nguyễn Trãi...).
-- =============================================================================

WITH x AS (
    SELECT
        stks.thu_tu,
        stks.kh_cu_moi,
        CASE WHEN stks.vk = 'expat' THEN 'exp' ELSE stks.vk END AS vk,
        stks.ten_khach,
        stks.line_id,
        stks.id,
        stks.ma_kh,
        stks.sdt,
        stks.ngay_den_cua,
        stks.loai_ban_ghi,
        stks.ngay_tao,
        stks.ngay_dc,
        stks.ngay_hl,
        stks.ngay_tt,
        stks.date_time,
        stks.ma_booking,
        stks.nhan_vien,
        stks.doanh_so,
        stks.tong_tien,
        stks.vao_so,
        stks.trang_thai,
        stks.line_tt,
        stks.phan_loai_khach,
        stks.loai_bk,
        stks.thuong_hieu,
        stks.nhom_dv,
        stks.ten_dv,
        stks.chi_nhanh,
        stks.chinhanhphanquyen,
        stks.phong_ban_nguoi_tao,
        stks.nguon_moi,
        stks.nhom_nguon_moi,
        stks.nguon_bk_id,
        stks.id_dv,
        stks.ma_phieu,
        stks.fk,
        stks.tien_ap,
        stks.reason_cancel_booking,
        CASE
            WHEN stks.nguon_moi IN ('MD - Tiktok', 'MD - Zalo', 'MKT_Zalo', 'MD - Youtube',
                                    'MD - Phát triển cộng đồng (Seeding)', 'MD - Phát triển cộng đồng')
                 THEN 'Khác'
            WHEN stks.nguon_moi ~~ '%Facebook%' THEN 'FB'
            WHEN stks.nguon_moi = 'MD - Search' THEN 'Web'
            WHEN stks.nguon_moi ~~ '%Seo%'      THEN 'Web'
            WHEN stks.nguon_moi ~~ '%Google%'   THEN 'Web'
            WHEN stks.nguon_moi ~~ '%Hotline%'  THEN 'Web'
            ELSE 'Khác'
        END                                                  AS kenh,
        COALESCE(rcs2.name, rcs1.name)                       AS state_name,
        COALESCE(rcs2.code, rcs1.code)                       AS state_code,
        COALESCE(rc2.name, rc1.name)                         AS quoc_gia,
        cl.ticket_id,
        NULL::text                                           AS ad_id,
        dkq.first_product_group                              AS nhom_dv_KH_quan_tam,
        dkq.first_product_category                           AS nhom_dv_KH_quan_tam_goc,
        CASE
            WHEN sbn.nhom_dich_vu_chinh IS NULL THEN NULL
            WHEN sbn.nhom_dich_vu_chinh = 'BEAUTY & SPA' THEN '8.BEAUTY & SPA'
            WHEN sbn.nhom_dich_vu_chinh = 'PTTM HÀM MẶT' THEN '3.HÀM MẶT/NHA KHOA'
            WHEN sbn.nhom_dich_vu_chinh = 'WELLNESS' THEN '9.WELLNESS'
            WHEN sbn.nhom_dich_vu_chinh = 'BÉO ĐA CHUYÊN KHOA' THEN '7.BÉO ĐA CHUYÊN KHOA'
            WHEN sbn.nhom_dich_vu_chinh = 'PTTM MẮT' THEN '1.MẮT'
            WHEN sbn.nhom_dich_vu_chinh = 'PTTM MŨI' THEN '2.MŨI'
            WHEN sbn.nhom_dich_vu_chinh = 'CẤY MỠ' THEN '5.CẤY MỠ'
            WHEN sbn.nhom_dich_vu_chinh = 'PTTM NGỰC/MÔNG' THEN '4.NGỰC/MÔNG'
            ELSE '6.DỊCH VỤ KHÁC'
        END                                                  AS nhom_dv_chinh_booking,
        COALESCE(us.name, monm.new_source_name)              AS nguon_moi_v2,
        cat.name                                             AS nhom_nguon_moi_v2
    FROM {{ ref('stg_common_tongquan_khachhang_da') }} stks
    JOIN {{ source('kangnam', 'crm_lead') }} cl
      ON cl.id = stks.id AND cl.brand_etl = 2
    LEFT JOIN {{ source('kangnam', 'res_country_state') }} rcs2
      ON rcs2.id = cl.state_id AND rcs2.brand_etl = 2
    LEFT JOIN {{ source('kangnam', 'res_country_state') }} rcs1
      ON rcs1.id = cl.state_id AND rcs1.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'res_country') }} rc2
      ON rc2.id = cl.country_id AND rc2.brand_etl = 2
    LEFT JOIN {{ source('kangnam', 'res_country') }} rc1
      ON rc1.id = cl.country_id AND rc1.brand_etl = 1
    LEFT JOIN {{ ref('stg_dv_khach_hang_quan_tam_da') }} dkq
      ON dkq.crm_id = cl.id AND dkq.brand_etl = cl.brand_etl
    LEFT JOIN {{ ref('stg_booking_nhom_dich_vu_chinh_da') }} sbn
      ON sbn.crm_id = cl.id AND sbn.brand_etl = cl.brand_etl
    -- Nguồn mới thật của Đông Á (hiện chưa lead nào có new_source_id)
    LEFT JOIN LATERAL (
        SELECT u.name, u.category_id
        FROM {{ source('kangnam', 'utm_source') }} u
        WHERE u.id = cl.new_source_id AND u.brand_etl = 2
        LIMIT 1
    ) us ON TRUE
    -- Fallback: suy nguồn mới từ nguồn cũ, ưu tiên mapping Đông Á rồi tới Kangnam
    LEFT JOIN LATERAL (
        SELECT m.new_source_name, m.new_source_category_id, m.brand_etl AS map_brand
        FROM {{ ref('m_utm_source_old_new_map') }} m
        WHERE m.old_source_id = cl.source_id AND m.brand_etl IN (2, 1)
          AND us.name IS NULL
        ORDER BY (m.brand_etl = 2) DESC, m.new_source_id
        LIMIT 1
    ) monm ON TRUE
    LEFT JOIN {{ source('kangnam', 'crm_category_source') }} cat
      ON cat.id = COALESCE(us.category_id, monm.new_source_category_id)
     AND cat.brand_etl = CASE WHEN us.category_id IS NOT NULL THEN 2 ELSE monm.map_brand END
),
kh AS (
    SELECT x.*,
           CASE WHEN x.state_name = 'Thành phố Hồ Chí Minh' THEN 'SÀI GÒN'
                WHEN x.state_name = 'Thành phố Hà Nội'       THEN 'Hà Nội'
                WHEN x.state_name IS NULL                      THEN 'KXĐ'
                WHEN x.state_code NOT LIKE '%VN-%'             THEN 'VIỆT KIỀU'
                ELSE x.state_name
           END AS local_k,
           CASE WHEN x.ngay_den_cua IS NOT NULL THEN x.sdt ELSE NULL END AS den_cua,
           CASE WHEN x.vk = 'marketing'   THEN 'VIỆT KIỀU'
                WHEN x.vk = 'mkt_oversea' THEN 'QUỐC TẾ'
                ELSE x.chi_nhanh
           END AS chi_nhanh_sm
    FROM x
)
SELECT kh.*,
       kh.nguon_moi      AS "Nguon",
       kh.nhom_nguon_moi AS "Nhom_nguon",
       kh.chi_nhanh_sm   AS chi_nhanh_new
FROM kh
