-- Tương đương subquery "new_transaction" bên trong df_fdate: các crm_id đánh số cũ (< 2174165, trước
-- khi tách hệ thống) còn phát sinh thanh toán gần đây, quét trên TOÀN BỘ stag_payment_transfer (mọi
-- brand) -- nay đọc thẳng từ bảng thật (đã coi là nguồn hợp lệ) thay vì phải tự dựng lại.
with all_crm as (
    select crm_id, payment_date from {{ ref('stg_sptr_legacy_brand0') }}
    union all
    select crm_id, payment_date from {{ ref('stg_sptr_legacy_brand134') }}
)
select distinct crm_id
from all_crm
where crm_id < 2174165
    and payment_date >= greatest(date_trunc('month', current_date - interval '1 month')::date, date '2025-12-01')
