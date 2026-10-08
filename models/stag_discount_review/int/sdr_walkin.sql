-- Bảng tạm "pk" của function gốc: phiếu khám Completed có dòng SO giá 0 (dịch
-- vụ làm theo liệu trình đã bán). duration = thứ tự lần khám của từng crm_line
-- (logic diempl), các model dùng bảng này join lấy duration = 1 (lần khám đầu).
-- Logic cũ (dungtv, đã bỏ): duration = date(close_walkin) - date(max(close_walkin))
-- theo (booking_id, product_id), join duration = 0.
-- Join / partition theo brand_etl (stag_products không có brand_etl -> chỉ product_id).

select
    wk.booking_id,
    wk.state,
    date(wk.date) as date,
    wk.close_walkin,
    date(min(wk.close_walkin) over (partition by wk.brand_etl, wk.booking_id, sol1.product_id)) as max_date,
    row_number() over (partition by wk.brand_etl, wk.booking_id, sol1.crm_line_id order by close_walkin) as duration,
    wk.name,
    sol1.product_id,
    sp_1.product,
    sol1.crm_line_id,
    wk.brand_etl
from {{ source('sdr_base', 'sh_medical_appointment_register_walkin') }} wk
left join {{ source('sdr_base', 'sale_order') }} sol
    on sol.id = wk.sale_order_id and sol.brand_etl = wk.brand_etl
left join {{ source('sdr_base', 'sale_order_line') }} sol1
    on sol.id = sol1.order_id and sol1.brand_etl = sol.brand_etl
left join {{ ref('stag_products') }} sp_1 on sp_1.product_id = sol1.product_id
where wk.state::text = 'Completed'::text
    and sol1.price_subtotal = 0
