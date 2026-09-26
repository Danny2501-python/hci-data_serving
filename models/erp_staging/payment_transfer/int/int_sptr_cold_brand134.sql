-- Phần "nguội" của brand 1/3/4: các crm_id KHÔNG có giao dịch gần đây (không nằm trong
-- int_sptr_recent_crm_scope) -- giữ nguyên từ bảng đích thật, không tính lại (vì không thể: nguồn ERP
-- chi tiết không còn đủ lịch sử). Tương đương phần dữ liệu mà write_stag_payment_transfer() không đụng
-- tới (DELETE chỉ xoá theo temp_crm_id_update).
--
-- ⚠ (2026-09-26) THÊM: với crm_id CÓ giao dịch gần đây (nằm trong scope), vẫn giữ các dòng CŨ HƠN cửa sổ
-- tính lại (payment_date < đầu tháng trước, cùng mốc int_sptr_recent_crm_scope) mà phần tính lại
-- (int_sptr_final_calc) KHÔNG dựng ra (so theo id). Lý do: ERP chi tiết (crm_account_payment_detail...)
-- trên new_product chỉ còn ~4 tháng → loại toàn bộ crm_id trong scope làm rơi mất dòng cũ của khách vẫn
-- còn giao dịch gần đây. Đã đo sau khi khôi phục từ backup 2026-09-26: thiếu quy tắc này Kangnam
-- T8/2025-T5/2026 hụt 12-380 triệu/tháng, Paris T5/2026 hụt 52,9 triệu so với sandbox.
-- Trong cửa sổ tính lại, dòng của crm_id trong scope vẫn chỉ lấy từ phần tính lại (bản chuẩn).
select l.*
from {{ ref('stg_sptr_legacy_brand134') }} l
where not exists (
    select 1 from {{ ref('int_sptr_recent_crm_scope') }} s
    where s.crm_id = l.crm_id and s.brand_etl = l.brand_etl
)
or (
        l.payment_date < greatest(date_trunc('month', current_date - interval '1 month')::date, date '2025-12-01')
    and not exists (
        select 1 from {{ ref('int_sptr_final_calc') }} f
        where f.id = l.id
    )
)
