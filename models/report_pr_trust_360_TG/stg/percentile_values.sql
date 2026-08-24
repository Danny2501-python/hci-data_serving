SELECT
        -- Chờ trước TP (phút)
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY "chờ trước tp (phút)")            AS cho_p25,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY "chờ trước tp (phút)")            AS cho_p50,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY "chờ trước tp (phút)")            AS cho_p75,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY "chờ trước tp (phút)")            AS cho_p99,
        -- Phục vụ (phút)
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY "phục vụ (phút)")                 AS pv_p25,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY "phục vụ (phút)")                 AS pv_p50,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY "phục vụ (phút)")                 AS pv_p75,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY "phục vụ (phút)")                 AS pv_p99,
        -- Tổng thời gian tại CN (phút)
        -- Cột này đang lưu dạng TEXT trong bảng nên phải ép kiểu ::numeric mới dùng được PERCENTILE_CONT
        -- NULLIF(...,'') để tránh lỗi khi ép kiểu chuỗi rỗng '' sang numeric
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY NULLIF("tổng thời gian tại cn (phút)", '')::numeric)   AS tong_p25,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY NULLIF("tổng thời gian tại cn (phút)", '')::numeric)   AS tong_p50,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY NULLIF("tổng thời gian tại cn (phút)", '')::numeric)   AS tong_p75,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY NULLIF("tổng thời gian tại cn (phút)", '')::numeric)   AS tong_p99
    FROM {{ source('ParisTrust360', 'pr_trust_360_data_thoi_gian_phuc_vu') }}