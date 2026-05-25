-- =============================================================================
-- int_frmack_fb_cost  (Pass 1.2)
-- Facebook cost with full campaign mapping, chi_nhanh and local_k.
-- Reads from stg_frmack_fb_insight.
-- =============================================================================
WITH fb AS (
    SELECT
        CASE WHEN s.cn ILIKE '%Hai Ngoai%' or s.cn = 'vki' THEN 'VIỆT KIỀU'
             WHEN s.cn ILIKE '%QUOC TE%' or s.cn = 'qte'  THEN 'QUỐC TẾ'
             WHEN s.cn IN ('exp','expat')  THEN 'exp'
             ELSE 'no'
        END                                                        AS vk,
        s.camp_name, s.ngay_chi_phi, s.vung, s.type_data,
        s.page_id, s.account_fb, s.chi_phi,
        CASE WHEN s.chi_nhanh_no_camp IS NULL AND (s.cn NOT ILIKE '%QUOC TE%' or s.cn = 'vki') THEN 'VIỆT KIỀU'
             WHEN s.chi_nhanh_no_camp IS NULL AND (s.cn     ILIKE '%QUOC TE%' or s.cn = 'qte') THEN 'QUỐC TẾ'
             ELSE s.chi_nhanh_no_camp
        END                                                        AS chi_nhanh_inter,
        CASE WHEN cns.nhom_dv IS NULL THEN cns2.nhom_dv
             ELSE cns.nhom_dv
        END                                                        AS nhom_dv_sys
    FROM {{ ref('stg_frmack_fb_insight_v3') }} s
    LEFT JOIN LATERAL (
        SELECT nhom_dv FROM {{ source('kangnam', 'campaign_name_split') }}
        WHERE UPPER(campain_name_split) = UPPER(s.nhom_dv) LIMIT 1
    ) cns  ON TRUE
    LEFT JOIN LATERAL (
        SELECT nhom_dv FROM {{ source('kangnam', 'campaign_name_split') }}
        WHERE UPPER(campain_name_split) = (s.nhom_dv2) LIMIT 1
    ) cns2 ON TRUE
)
SELECT
    fb.camp_name,
    fb.vk,
    'DV'::text  AS ten_dv,
    'CP'::text  AS nguon,
    'CP'::text  AS nhom_nguon,
    'FB'::text  AS kenh,
    fb.ngay_chi_phi AS ngay,
    fb.nhom_dv_sys,
    CASE UPPER(fb.chi_nhanh_inter)
        WHEN 'HCM'            THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
        WHEN 'HỒ CHÍ MINH'   THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
        WHEN 'HÀ NỘI'         THEN 'BỆNH VIỆN KANGNAM HÀ NỘI'
        WHEN 'BẮC NINH'       THEN 'VIỆN THẨM MỸ KANGNAM BẮC NINH'
        WHEN 'HẢI PHÒNG'      THEN 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'
        WHEN 'BUÔN MÊ THUỘT'  THEN 'VIỆN THẨM MỸ KANGNAM BUÔN MA THUỘT'
        WHEN 'ĐÀ NẴNG'        THEN 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'
        WHEN 'CẦN THƠ'        THEN 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'
        WHEN 'NGHỆ AN'        THEN 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'
        WHEN 'THÁI NGUYÊN'    THEN 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN'
        WHEN 'THANH HÓA'      THEN 'VIỆN THẨM MỸ KANGNAM THANH HÓA'
        WHEN 'BÌNH DƯƠNG'     THEN 'VIỆN THẨM MỸ KANGNAM BÌNH DƯƠNG'
        WHEN 'VINH'           THEN 'VIỆN THẨM MỸ KANGNAM VINH'
        ELSE fb.chi_nhanh_inter
    END                                                            AS chi_nhanh,
    CASE fb.vung
        WHEN 'Ho Chi Minh City' THEN 'SÀI GÒN'
        WHEN 'Hanoi'            THEN 'Hà Nội'
        WHEN 'Da Nang'          THEN 'Thành phố Đà Nẵng'
        WHEN 'Cần Thơ'          THEN 'Thành phố Cần Thơ'
        WHEN 'Haiphong'         THEN 'Thành phố Hải Phòng'
        ELSE CASE
            WHEN fb.chi_nhanh_inter ILIKE '%VIỆT KIỀU%' THEN 'VIỆT KIỀU'
            WHEN fb.chi_nhanh_inter ILIKE '%QUỐC TẾ%'  THEN 'QUỐC TẾ'
            ELSE 'Tỉnh ' || regexp_replace(fb.vung, '\s*Province$', '')
        END
    END                                                            AS local_k,
    CASE WHEN fb.chi_nhanh_inter = 'VIỆT KIỀU' THEN 'VIỆT KIỀU'
         WHEN fb.chi_nhanh_inter = 'QUỐC TẾ'  THEN 'QUỐC TẾ'
         ELSE 'Việt Nam'
    END                                                            AS quoc_gia,
    fb.chi_phi::text AS metric,
    fb.type_data,
    fb.page_id,
    fb.account_fb
FROM fb
