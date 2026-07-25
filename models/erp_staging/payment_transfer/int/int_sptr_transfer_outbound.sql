-- Tương đương dfo trong get_data_payment(): vế "outbound" của phiếu điều chuyển — dùng thông tin
-- Dòng dịch vụ/sản phẩm phía "from" (hậu tố _f), map về đúng tên cột như dfpm (query_pm) để union được.
select
    concat('to-', id) as id,
    product_typef as product_type,
    ma_phieu, crm_id, payment_date, payment_method, communication,
    clineidf as clineid,
    product_idf as product_id,
    quantityf as quantity,
    uom_pricef as uom_price,
    number_usedf as number_used,
    totalf as total,
    total_receivedf as total_received,
    total_received_clinef as total_received_cline,
    -transfer_amount as payment,
    'outbound' as payment_type,
    stage_productf as stage_product,
    consultants_1f as consultants_1,
    consulting_role_1f as consulting_role_1,
    consultants_2f as consultants_2,
    consulting_role_2f as consulting_role_2,
    ho_trof as ho_tro,
    price_list_idf as price_list_id,
    orgcompany_id, company_idf as company_id,
    write_date, brand_id, brand_etl
from {{ ref('int_sptr_transfer_base') }}
