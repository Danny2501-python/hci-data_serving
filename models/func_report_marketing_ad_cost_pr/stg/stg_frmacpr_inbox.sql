-- =============================================================================
-- stg_frmacpr_inbox
-- PASS 14: Inbox Facebook Paris – số cuộc trò chuyện bắt đầu qua tin nhắn.
-- =============================================================================
WITH a AS (
    SELECT
        ipf.ngày                                                    AS date_raw,
        ipf."số cuộc trò chuyện bắt đầu qua tin nhắn"             AS ib,
        lpa.branch,
        SPLIT_PART("tên quảng cáo", '_', 2)                       AS nhom_dv_raw
    FROM {{ source('paris', 'inbox_paris_fb') }} ipf
    LEFT JOIN {{ source('paris', 'local_paris_adnet') }} lpa
           ON lpa.province = ipf.vùng
),

b AS (
    SELECT
        'FB'::text                                                  AS channel,
        date_raw::date                                              AS ngay,
        CASE nhom_dv_raw
            WHEN 'NRKT'      THEN 'Niềng răng khay trong'
            WHEN 'PTHM'      THEN 'PTHM'
            WHEN 'RANG SU'   THEN 'Răng sứ'
            WHEN 'IMPLANT'   THEN 'Implant'
            WHEN 'NIENG RANG' THEN 'Niềng răng mắc cài'
            ELSE nhom_dv_raw
        END                                                         AS nhom_dv,
        CASE UPPER(branch)
            WHEN 'HÀ NỘI'                        THEN 'HÀ NỘI'
            WHEN 'HỒ CHÍ MINH'                   THEN 'HỒ CHÍ MINH'
            WHEN 'NHA KHOA PARIS BẮC NINH'       THEN 'BẮC NINH'
            WHEN 'NHA KHOA PARIS HẢI PHÒNG'      THEN 'HẢI PHÒNG'
            WHEN 'NHA KHOA PARIS BUÔN MÊ THUỘT'  THEN 'BUÔN MÊ THUỘT'
            WHEN 'NHA KHOA PARIS ĐÀ NẴNG'        THEN 'ĐÀ NẴNG'
            WHEN 'NHA KHOA PARIS VINH'            THEN 'VINH'
            WHEN 'NHA KHOA PARIS THÁI NGUYÊN'    THEN 'THÁI NGUYÊN'
            WHEN 'NHA KHOA PARIS THANH HÓA'      THEN 'THANH HÓA'
            WHEN 'NHA KHOA PARIS BÌNH DƯƠNG'     THEN 'BÌNH DƯƠNG'
            WHEN 'NHA KHOA PARIS QUẢNG NINH'     THEN 'QUẢNG NINH'
            ELSE UPPER(branch)
        END                                                         AS chi_nhanh,
        ib
    FROM a
    WHERE ib IS NOT NULL
)

SELECT
    'MD - Facebook'::text       AS nguon,
    'MD'::text                  AS nhom_nguon,
    channel,
    ngay,
    nhom_dv,
    chi_nhanh,
    SUM(ib)::text               AS metric,
    'ib'::text                  AS type_data,
    -- Không có liên kết CRM, nhưng nhánh này là Inbox Facebook (nguon =
    -- 'MD - Facebook' ở trên) -> mặc định cứng theo catalog utm_source thật
    -- của Paris (id=731 'Facebook', category 'Online').
    'Facebook'::text            AS nguon_moi_v2,
    'Online'::text               AS nhom_nguon_moi_v2
FROM b
GROUP BY channel, ngay, nhom_dv, chi_nhanh
