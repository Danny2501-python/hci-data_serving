{{ config(alias='stag_discount_review_new_new') }}

-- Thay thế public.func_stag_discount_review_new_new() — phần 1 (bảng
-- stag_discount_review_new_new): BÁO CÁO TỔNG KHUYẾN MẠI (bóc tách SM - CS).
-- Pass 9: mỗi line lấy phiếu đầu tiên (no_tt = 1), bỏ line cancel, chỉ giữ
-- booking (brand_etl, crm_id) có ít nhất 1 line có total_discount <> 0.
-- Cột liệt kê tường minh: giữ ĐÚNG thứ tự cột của function gốc, không xuất
-- cột kỹ thuật brand_etl.

with a as (
    select * from {{ ref('sdr_line_discount') }} od
    where no_tt = 1 and stage <> 'cancel'
),
b as (
    select a.brand_etl, a.crm_id from a where a.total_discount <> 0 group by a.brand_etl, a.crm_id
)
select
    type_data, clineid, crm_id, "source", category_source_code, category_source, stage,
    total_before_discount, total_discount, "%discount", quantity, uom_price, price_min_new,
    amout_test_discount, amout_test_discount_cs, total, discount_percent, discount_cash,
    other_discount, sale_to, discount_cs_percent, discount_cs_amount, total_discount_review,
    price_min, discount_review_id, discount_special, deep_approve_user, payment_date, id,
    ma_phieu, payment_type, smhcsid, product_id, product_ctg_id, product_category, product,
    max_date, payment, dim_date, company_id, coupon_name, voucher_name, type_discount,
    discount_coupon, service_min, campaign_coupon, campaign_voucher, amount_discount_coupon,
    amount_discount_voucher, discount_mkt, discount_cs, create_date, arrival_date, booking,
    contact_name, code_customer, stage_bk, type_crm_id, brand_id_bk, company_id_bk, cnpq,
    campaign, amount_price_min, over_discount_mkt, over_discount_cs, trang_thai,
    no_payment_by_line, no_id, company_id_pq, brand_id_pq, chinhanh, thuonghieu, no_tt,
    cummulative_line
from a
where exists (select 1 from b where b.brand_etl = a.brand_etl and b.crm_id = a.crm_id)
