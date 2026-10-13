-- Lọc is_delete=true — xem chú thích đầy đủ ở stg_sptr_crm_account_payment_detail.sql (cùng lỗi,
-- cùng cách xử lý).
-- (2026-10-13) Bỏ thêm dòng chi tiết "ma" của phiếu bị phân bổ lại (ERP xoá cứng dòng cũ, sync không bắt
-- được) — xem macros/sptr_phieu_phan_bo_lai.sql.
select d.*
from {{ source('sptr_erp', 'crm_account_payment_product_detail') }} d
left join {{ sptr_phieu_phan_bo_lai() }} pl
  on pl.brand_etl = d.brand_etl and pl.account_payment_id = d.account_payment_id
where coalesce(d.is_delete, false) = false
  and not (pl.account_payment_id is not null and d.create_date < pl.max_create_date - interval '1 minute')
