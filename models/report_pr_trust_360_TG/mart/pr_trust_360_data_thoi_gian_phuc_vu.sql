{{
  config(
    materialized = 'table',
    alias        = 'pr_trust_360_data_thoi_gian_phuc_vu_v2'
  )
}}

SELECT
    t."ngày đo lường",
    t."tuần",
    t."cn",
    t."dịch vụ",
    t."touchpoint",
    t."giờ bắt đầu",
    t."giờ kết thúc",
    t."chờ trước tp (phút)",
    t."phục vụ (phút)",
    t."snapshot_date",
    t."ingestion_timestamp",
    t."source_server",
    t."tổng thời gian tại cn (phút)",
    t."tên kh",
    -- Nhóm phân vị của "chờ trước tp (phút)"
    CASE
        WHEN t."chờ trước tp (phút)" IS NULL          THEN NULL
        WHEN t."chờ trước tp (phút)" <= pv.cho_p25     THEN 'P25'
        WHEN t."chờ trước tp (phút)" <= pv.cho_p50     THEN 'P50'
        WHEN t."chờ trước tp (phút)" <= pv.cho_p75     THEN 'P75'
        WHEN t."chờ trước tp (phút)" <= pv.cho_p99     THEN 'P99'
        ELSE '>P99'
    END AS Phan_vi_cho_truoc_tp,
    -- Nhóm phân vị của "phục vụ (phút)"
    CASE
        WHEN t."phục vụ (phút)" IS NULL                THEN NULL
        WHEN t."phục vụ (phút)" <= pv.pv_p25            THEN 'P25'
        WHEN t."phục vụ (phút)" <= pv.pv_p50            THEN 'P50'
        WHEN t."phục vụ (phút)" <= pv.pv_p75            THEN 'P75'
        WHEN t."phục vụ (phút)" <= pv.pv_p99            THEN 'P99'
        ELSE '>P99'
    END AS Phan_vi_phuc_vu,
    -- Nhóm phân vị của "tổng thời gian tại cn (phút)" (đã ép kiểu text -> numeric)
    CASE
        WHEN NULLIF(t."tổng thời gian tại cn (phút)", '') IS NULL                            THEN NULL
        WHEN NULLIF(t."tổng thời gian tại cn (phút)", '')::numeric <= pv.tong_p25             THEN 'P25'
        WHEN NULLIF(t."tổng thời gian tại cn (phút)", '')::numeric <= pv.tong_p50             THEN 'P50'
        WHEN NULLIF(t."tổng thời gian tại cn (phút)", '')::numeric <= pv.tong_p75             THEN 'P75'
        WHEN NULLIF(t."tổng thời gian tại cn (phút)", '')::numeric <= pv.tong_p99             THEN 'P99'
        ELSE '>P99'
    END AS Phan_vi_tong_thoi_gian_tai_cn
FROM {{ source('ParisTrust360', 'pr_trust_360_data_thoi_gian_phuc_vu') }} t
CROSS JOIN {{ ref('percentile_values') }} pv