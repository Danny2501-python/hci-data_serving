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
        CASE WHEN stks.nguon_moi ~~ '%Facebook%' THEN 'FB'
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
        cl.ticket_id
    FROM {{ ref('stg_common_tongquan_khachhang') }} stks
    JOIN {{ source('kangnam', 'crm_lead') }} cl
      ON cl.id = stks.id AND cl.brand_etl = 1 AND cl.create_by_department IS NOT NULL
    LEFT JOIN {{ source('kangnam', 'res_country_state') }} rcs
      ON rcs.id = cl.state_id  AND rcs.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'res_country') }} rc
      ON rc.id  = cl.country_id AND rc.brand_etl = 1
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
