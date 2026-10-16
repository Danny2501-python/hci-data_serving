-- SĐT THÔ: TOÀN BỘ lead (crm_lead type_crm_id = 1, active) của Hồng Hà (4) /
-- Tiêu hóa Việt (8) theo ngày tạo (create_time +7h giờ VN). KHÔNG lọc trạng
-- thái, KHÔNG lọc dịch vụ; CHỈ nguồn MD (Vãng lai tính MD trước T10/2026) —
-- khác rhtdk_sdt (SĐT verify) ở chỗ không lọc stage 7/8/18. co_line chỉ đánh
-- dấu có dịch vụ. Base: rhtdk_lead_base.
--
-- [2026-10-15] rnk_sdt: thứ tự lần tạo lead của SĐT (1 = lần tạo ĐẦU TIÊN), xếp
-- theo create_time rồi lead_id trên TOÀN BỘ lịch sử crm_lead (type 1, active,
-- MỌI nguồn, MỌI trạng thái) của từng brand_etl. Chỉ ĐÁNH DẤU, KHÔNG lọc
-- (người dùng lọc rnk_sdt = 1 ở báo cáo khi cần "chỉ lần tạo đầu tiên"). Lead
-- không có SĐT: mỗi lead tự là 1 (không gộp được).

with lead_dau_tien as (
    select
        lb.*,
        row_number() over (
            partition by lb.brand_etl,
                         coalesce(nullif(trim(lb.phone), ''), 'lead_id:' || lb.lead_id::text)
            order by lb.create_time, lb.lead_id
        ) as rn_sdt
    from {{ ref('rhtdk_lead_base') }} lb
    where lb.type_crm_id = 1
      and lb.create_time is not null
)

select
    brand_etl,
    ten_thuong_hieu,
    date(create_time)                                    as ngay,
    create_time,
    ma_lead                                     as booking,
    contact_name,
    phone,
    code_customer,
    co_line,
    rn_sdt                                      as rnk_sdt,
    erp_source_id_old                           as source_id,
    old_source_name                             as source_name,
    erp_source_id_new                           as new_source_id,
    new_source_name,
    -- Vãng lai: MD trước T10/2026, ML từ T10/2026 (giống THV/rhtdk_hh)
    case
        when nhom_md_ml_raw = 'VL' then
            case when create_time >= date '2026-10-01' then 'ML' else 'MD' end
        else nhom_md_ml_raw
    end                                         as nhom_md_ml_baocao
from lead_dau_tien
where true
  -- Chỉ lấy nguồn MD (yêu cầu người dùng); Vãng lai tính MD trước T10/2026.
  and (
      nhom_md_ml_raw = 'MD'
      or (nhom_md_ml_raw = 'VL' and create_time < date '2026-10-01')
  )
