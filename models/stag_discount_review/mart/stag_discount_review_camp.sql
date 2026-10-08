{{ config(alias='stag_discount_review_camp') }}

-- Thay thế public.func_stag_discount_review_new_new() — phần 2 (bảng
-- stag_discount_review_camp): số tiền KM coupon/voucher theo chiến dịch.
-- Pass camp_4: chi nhánh/thương hiệu phân quyền, mỗi (brand_etl, booking, line,
-- name_km) lấy phiếu đầu tiên (no_tt = 1), bỏ line cancel.
-- Khác function gốc: chi nhánh/thương hiệu lấy từ m_res_company (+ res_brand)
-- join id + brand_etl thay cho res_company_trans_field; order by của no_tt dùng
-- mrc.id (tương đương company_new.id cũ — union camp không có cột id).
-- Cột liệt kê tường minh: giữ ĐÚNG thứ tự cột của function gốc, không xuất brand_etl.

with output_data_2 as (
    select
        d.*,
        mrc.id as company_id_pq,
        mrc.brand_id as brand_id_pq,
        mrc."name" "chinhanh",
        rb."name" "thuonghieu",
        row_number() over (partition by d.brand_etl, d.crm_id, d.clineid, name_km order by dim_date, mrc.id) no_tt
    from (select * from {{ ref('sdr_camp_union') }} where dim_date is not null) d
    left join {{ source('sdr_base', 'm_res_company') }} mrc
        on mrc.id = d.cnpq and mrc.brand_etl = d.brand_etl
    left join {{ source('sdr_base', 'res_brand') }} rb
        on rb.id = mrc.brand_id and rb.brand_etl = mrc.brand_etl
)
select
    "table", type_data, clineid, crm_id, booking, code_customer, customer_name, "source",
    category_source_code, cnpq, stage, total_before_discount, quantity, uom_price,
    product_category, product, dim_date, campaign_name, name_km, type_discount, discount,
    amount_discount, service_min, company_id_pq, brand_id_pq, chinhanh, thuonghieu, no_tt
from output_data_2 od
where no_tt = 1 and stage <> 'cancel'
