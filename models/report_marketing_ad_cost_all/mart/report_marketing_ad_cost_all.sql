{{
  config(
    materialized = 'table',
    schema       = 'sandbox_mkt',
    alias        = 'report_marketing_ad_cost_all',
    tags         = ['mkt_all']
  )
}}
-- =============================================================================
-- report_marketing_ad_cost_all — báo cáo marketing TỔNG HỢP nhiều brand (thị trường trong nước).
-- Bảng: public_sandbox_mkt.report_marketing_ad_cost_all (schema 'sandbox_mkt' → dbt mặc định thêm
-- tiền tố target schema; KHÔNG sửa macro generate_schema_name dùng chung).
-- Nguyên tắc: cái gì các brand đã có CHUNG thì gom; cái gì chưa khớp giữ nguyên / để trống, map sau.
-- Model chỉ ĐỌC kết quả của các model marketing sẵn có (không sửa logic từng brand) → số từng brand
-- luôn khớp báo cáo riêng:
--   * Kangnam : mart_report_marketing_ad_cost_kn  (public.report_marketing_ad_cost_kn_v2)
--   * Paris   : mart_report_marketing_ad_cost_pr  (public.report_marketing_ad_cost_pr_v2)
-- Cột: 26 cột giống hệt report_marketing_ad_cost_kn_v2 (tên, thứ tự) + cột `brand` ở cuối
--   → Tableau Kangnam chỉ cần đổi nguồn bảng + thêm bộ lọc brand.
-- Paris: `dt` → Metric; `date` (timestamp) → date; chưa có nhom_dv_kh_quan_tam_goc → NULL (map sau).
-- type_data: đổi tên Paris về chuẩn Kangnam khi CÙNG ý nghĩa: ib → inbox, google → Google_cd,
--   Deal_cs → DealCS. Loại chỉ Paris có (BK, tiktok) giữ nguyên tên – map sau.
-- CHƯA gom (làm sau): Sunwoo (dự án nước ngoài, khác tiền tệ – để riêng), Hồng Hà, Tiêu Hóa Việt
--   (chưa có model marketing); cột riêng Paris (product_type, product_category).
-- =============================================================================
WITH kn AS (
    SELECT
        k.vk::text, k.ten_dv::text, k."Nguon"::text, k."Nhom_nguon"::text, k.kenh::text,
        k."date"::date, k.nhom_dv::text, k.chi_nhanh::text, k.local_k::text, k.quoc_gia::text,
        k.chau_luc::text, k."Metric"::text, k.type_data::text, k.page::text, k.page_id::text,
        k.region::text, k.tinh_noi::text, k.campaign::text, k.account_fb::text, k.actor::text,
        k.nhom_dv_muc_tieu::text, k.nhom_dv_kh_quan_tam::text, k.nhom_dv_kh_quan_tam_goc::text,
        k.nhom_dv_chinh_booking::text, k.nguon_moi_v2::text, k.nhom_nguon_moi_v2::text,
        'Kangnam'::text AS brand
    FROM {{ ref('mart_report_marketing_ad_cost_kn') }} k
),
pr AS (
    SELECT
        p.vk::text, p.ten_dv::text, p.nguon::text, p.nhom_nguon::text, p.kenh::text,
        p."date"::date, p.nhom_dv::text, p.chi_nhanh::text, p.local_k::text, p.quoc_gia::text,
        p.chau_luc::text,
        p.dt::text,                                              -- Paris: cột giá trị tên dt
        CASE p.type_data                                         -- cùng ý nghĩa → tên chuẩn Kangnam
            WHEN 'ib'      THEN 'inbox'
            WHEN 'google'  THEN 'Google_cd'
            WHEN 'Deal_cs' THEN 'DealCS'
            ELSE p.type_data                                     -- BK, tiktok… giữ nguyên (map sau)
        END::text,
        p.page::text, p.page_id::text,
        p.region::text, p.tinh_noi::text, p.campaign::text, p.account_fb::text, p.actor::text,
        p.nhom_dv_muc_tieu::text, p.nhom_dv_kh_quan_tam::text,
        NULL::text,                                              -- nhom_dv_kh_quan_tam_goc: Paris chưa có
        p.nhom_dv_chinh_booking::text, p.nguon_moi_v2::text, p.nhom_nguon_moi_v2::text,
        'Paris'::text
    FROM {{ ref('mart_report_marketing_ad_cost_pr') }} p
)
SELECT * FROM kn
UNION ALL
SELECT * FROM pr
