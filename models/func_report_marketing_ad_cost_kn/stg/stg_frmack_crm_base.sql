-- =============================================================================
-- stg_frmack_crm_base  (Pass 2.1 + 2.4)
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
        -- [Sửa 2026-08-31 — xem README.md mục 20] Ưu tiên channel/utm_source THẬT của
        -- ticket (ctsd) trước khi fallback về text-match trên nguon_moi — tránh 2 lỗi:
        -- (1) Google Ads Search/Display trả phí bị rơi vào 'Khác' vì nguon_moi='MD - Search'
        --     không chứa chữ "Google", và ctsd.source_name có chứa 'utm_source' nên trượt
        --     luôn nhánh fallback SEO cũ;
        -- (2) ticket channel='Web' (SEO/Google Ads thật) nhưng nguon_moi bị gán nhầm
        --     Facebook... vẫn bị tính vào kênh đó thay vì Web.
        -- [Sửa 2026-08-31 — xem README.md mục 21] Chặn RIÊNG nhóm "Cộng đồng"
        -- (Tiktok/Zalo/Youtube/Phát triển cộng đồng) về thẳng 'Khác' TRƯỚC khi xét
        -- channel/utm_source — an toàn cho các sheet/tính toán khác lỡ đọc thẳng cột
        -- `kenh` (không qua công thức "Platform kênh" của Tableau, vốn đã tách nhóm
        -- này ra thành 'Cộng đồng' bằng điều kiện riêng trên Nguon) — tránh trường hợp
        -- ticket của nhóm này đi qua channel='Web' bị gộp nhầm vào Web/Web - SEO.
        CASE WHEN stks.nguon_moi IN ('MD - Tiktok','MD - Zalo','MKT_Zalo','MD - Youtube',
                                      'MD - Phát triển cộng đồng (Seeding)','MD - Phát triển cộng đồng')
                  THEN 'Khác'
             WHEN ctsd.channel ILIKE 'web'
                  AND (ctsd.utm_source ILIKE '%google%search%' OR ctsd.utm_source ILIKE '%google%display%')
                  THEN 'Web'
             WHEN ctsd.channel ILIKE 'web' AND ctsd.source_name ILIKE '%Web%'       THEN 'Web - SEO'
             WHEN stks.nguon_moi ~~ '%Facebook%' THEN 'FB'
             WHEN stks.nguon_moi ~~ '%Seo%'      THEN 'Web'
             WHEN stks.nguon_moi ~~ '%Google%'   THEN 'Web'
             WHEN stks.nguon_moi ~~ '%Hotline%'  THEN 'Web'
             ELSE 'Khác'
        END                                                  AS kenh,
        CASE WHEN rcs.name = 'Thành phố Hồ Chí Minh' THEN 'SÀI GÒN'
             WHEN rcs.name = 'Thành phố Hà Nội'       THEN 'Hà Nội'
             WHEN rcs.name IS NULL                      THEN 'KXĐ'
             WHEN rcs.code NOT LIKE '%VN-%'             THEN 'VIỆT KIỀU'
             ELSE rcs.name
        END                                                  AS local_k,
        rc.name                                              AS quoc_gia,
        cl.ticket_id, SUBSTRING(cta.ad_id_value FROM '\d+') AS ad_id,
        dkq.first_product_group AS nhom_dv_KH_quan_tam,
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
        END AS nhom_dv_chinh_booking,
        COALESCE(us.name, monm.new_source_name) AS nguon_moi_v2,
        cat.name AS nhom_nguon_moi_v2
    FROM {{ ref('stg_common_tongquan_khachhang') }} stks
    JOIN {{ source('kangnam', 'crm_lead') }} cl
      ON cl.id = stks.id AND cl.brand_etl = 1
      -- KHÔNG lọc cl.create_by_department IS NOT NULL ở đây nữa — xem mục 19
      -- README.md: điều kiện này loại nhầm toàn bộ lead nguồn "Tái khai thác"
      -- (create_by_department luôn NULL cho nhóm này) ra khỏi model.
    LEFT JOIN {{ source('kangnam', 'res_country_state') }} rcs
      ON rcs.id = cl.state_id  AND rcs.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'res_country') }} rc
      ON rc.id  = cl.country_id AND rc.brand_etl = 1
     LEFT JOIN {{ source('kangnam', 'cs_ticket_api') }} cta
      ON cta.ticket_id  = cl.ticket_id AND cta.brand_id = 1
    left join {{ source('kangnam', 'cs_ticket_source_api') }} cts
      on cts.ticket_id = cta.ticket_id 
    left join {{ source('kangnam', 'cs_ticket_source_detail_api') }} ctsd
      on ctsd.id = cts.ticket_source_detail_id
     LEFT JOIN {{ ref('stg_dv_khach_hang_quan_tam') }} dkq
      ON dkq.crm_id = cl.id AND dkq.brand_etl = cl.brand_etl
     LEFT JOIN {{ ref('stg_booking_nhom_dich_vu_chinh') }} sbn
      ON sbn.crm_id = cl.id AND sbn.brand_etl = cl.brand_etl
     LEFT JOIN {{ source('kangnam', 'utm_source') }} us
      ON us.id = cl.new_source_id AND us.brand_id = cl.brand_etl
     -- Fallback khi crm_lead.new_source_id NULL: suy ra nguồn mới từ nguồn cũ
     -- (cl.source_id) qua bảng mapping master_data.m_utm_source_old_new_map.
     -- LATERAL + ORDER BY new_source_id LIMIT 1 để tránh fan-out — 3 old_source_id
     -- trong bảng mapping map sang >1 new_source_id (xem LOGIC.md/README.md), nếu
     -- JOIN thẳng sẽ nhân dòng lead.
     LEFT JOIN LATERAL (
        SELECT new_source_name, new_source_category_id
        FROM {{ ref('m_utm_source_old_new_map') }} m
        WHERE m.old_source_id = cl.source_id AND m.brand_etl = cl.brand_etl
          AND cl.new_source_id IS NULL
        ORDER BY m.new_source_id
        LIMIT 1
     ) monm ON TRUE
     LEFT JOIN {{ source('kangnam', 'crm_category_source') }} cat
      ON cat.id = COALESCE(us.category_id, monm.new_source_category_id) AND cat.brand_etl = cl.brand_etl
),
kh AS (
    SELECT x.*,
           CASE WHEN x.ngay_den_cua IS NOT NULL THEN x.sdt ELSE NULL END AS den_cua,
           CASE WHEN x.vk = 'marketing'   THEN 'VIỆT KIỀU'
                WHEN x.vk = 'mkt_oversea'  THEN 'QUỐC TẾ'
                ELSE x.chi_nhanh
           END AS chi_nhanh_sm
    FROM x
)
SELECT kh.*,
       kh.nguon_moi         AS "Nguon",
       kh.nhom_nguon_moi    AS "Nhom_nguon",
       CASE WHEN kh.chi_nhanh_sm = 'VIỆN THẨM MỸ KANGNAM BẠCH MAI'  THEN 'BỆNH VIỆN KANGNAM HÀ NỘI'
            WHEN kh.chi_nhanh_sm = 'BỆNH VIỆN KANGNAM NGUYỄN TRÃI'   THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
            WHEN kh.chi_nhanh_sm = 'BỆNH VIỆN KANGNAM SÀI GÒN'       THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
            ELSE kh.chi_nhanh_sm
       END AS chi_nhanh_new
FROM kh
