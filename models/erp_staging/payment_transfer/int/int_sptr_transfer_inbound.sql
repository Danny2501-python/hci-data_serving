-- Tương đương dfi trong get_data_payment(): vế "inbound" của phiếu điều chuyển — dùng thông tin
-- Dòng dịch vụ/sản phẩm phía "to" (hậu tố _t).
select
    concat('ti-', id) as id,
    product_typet as product_type,
    ma_phieu, crm_id, payment_date, payment_method, communication,
    clineidt as clineid,
    product_idt as product_id,
    quantityt as quantity,
    uom_pricet as uom_price,
    number_usedt as number_used,
    totalt as total,
    total_receivedt as total_received,
    total_received_clinet as total_received_cline,
    transfer_amount as payment,
    'inbound' as payment_type,
    stage_productt as stage_product,
    consultants_1t as consultants_1,
    consulting_role_1t as consulting_role_1,
    consultants_2t as consultants_2,
    consulting_role_2t as consulting_role_2,
    ho_trot as ho_tro,
    price_list_idt as price_list_id,
    orgcompany_id, company_idt as company_id,
    write_date, brand_id, brand_etl
from {{ ref('int_sptr_transfer_base') }}
