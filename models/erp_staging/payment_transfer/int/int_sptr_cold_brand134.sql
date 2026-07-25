-- Phần "nguội" của brand 1/3/4: các crm_id KHÔNG có giao dịch gần đây (không nằm trong
-- int_sptr_recent_crm_scope) -- giữ nguyên từ bảng đích thật, không tính lại (vì không thể: nguồn ERP
-- chi tiết không còn đủ lịch sử). Tương đương phần dữ liệu mà write_stag_payment_transfer() không đụng
-- tới (DELETE chỉ xoá theo temp_crm_id_update).
select l.*
from {{ ref('stg_sptr_legacy_brand134') }} l
where not exists (
    select 1 from {{ ref('int_sptr_recent_crm_scope') }} s
    where s.crm_id = l.crm_id and s.brand_etl = l.brand_etl
)
