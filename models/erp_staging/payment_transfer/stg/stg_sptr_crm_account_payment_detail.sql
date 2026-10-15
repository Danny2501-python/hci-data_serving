-- Lọc is_delete=true (tombstone CDC khi ERP sửa/huỷ phiếu — dòng cũ được giữ lại đánh dấu xoá thay
-- vì xoá vật lý) NGAY TẠI ĐÂY, trước khi vào int_sptr_payment_service.sql — nếu không lọc, phiếu đã
-- bị sửa/huỷ sẽ bị cộng dồn TRÙNG với bản thay thế trong stag_payment_transfer (đã xác minh thực tế
-- gây lệch doanh số Kangnam T8/2026 +56.300.000đ so với report_kpi_bonus_commission/Tableau đã
-- verify — xem lịch sử trao đổi 2026-09-08). ⚠ Đây là sai lệch so với bản Python gốc (gốc cũng
-- KHÔNG lọc is_delete — xem LOGIC.md/knowledge.md, đối chiếu 2026-07-25 khớp tuyệt đối 816,719 dòng
-- kể cả các dòng is_delete=true) — CỐ Ý khác bản gốc vì đã xác minh đây là lỗi thật, không phải hạn
-- chế thiết kế.
-- (2026-10-13) Bỏ thêm dòng chi tiết "ma" của phiếu bị phân bổ lại (ERP xoá cứng dòng cũ, sync không bắt
-- được) — xem macros/sptr_phieu_phan_bo_lai.sql.
select d.*
from {{ source('sptr_erp', 'crm_account_payment_detail') }} d
left join {{ sptr_phieu_phan_bo_lai() }} pl
  on pl.brand_etl = d.brand_etl and pl.account_payment_id = d.account_payment_id
where coalesce(d.is_delete, false) = false
  and not (pl.account_payment_id is not null and d.create_date < pl.max_create_date - interval '1 minute')
