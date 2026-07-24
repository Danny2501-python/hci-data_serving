-- Tương đương đoạn nối dfpm/dfo/dfi + fix product_id=0 trong get_data_payment() (dùng
-- int_sptr_fix_product_id — đọc trực tiếp từ bảng đích thật, giống 100% bản gốc).
with unioned as (
    select id, product_type, ma_phieu, crm_id, payment_date, payment_method, communication,
        clineid, product_id, quantity, uom_price, number_used, total, total_received, total_received_cline,
        payment, payment_type, stage_product, consultants_1, consulting_role_1, consultants_2, consulting_role_2,
        ho_tro, price_list_id, orgcompany_id, company_id, write_date, brand_id, brand_etl
    from {{ ref('int_sptr_payment_service') }}
    union all
    select id, product_type, ma_phieu, crm_id, payment_date, payment_method, communication,
        clineid, product_id, quantity, uom_price, number_used, total, total_received, total_received_cline,
        payment, payment_type, stage_product, consultants_1, consulting_role_1, consultants_2, consulting_role_2,
        ho_tro, price_list_id, orgcompany_id, company_id, write_date, brand_id, brand_etl
    from {{ ref('int_sptr_payment_cosmetic') }}
    union all
    select id, product_type, ma_phieu, crm_id, payment_date, payment_method, communication,
        clineid, product_id, quantity, uom_price, number_used, total, total_received, total_received_cline,
        payment, payment_type, stage_product, consultants_1, consulting_role_1, consultants_2, consulting_role_2,
        ho_tro, price_list_id, orgcompany_id, company_id, write_date, brand_id, brand_etl
    from {{ ref('int_sptr_transfer_outbound') }}
    union all
    select id, product_type, ma_phieu, crm_id, payment_date, payment_method, communication,
        clineid, product_id, quantity, uom_price, number_used, total, total_received, total_received_cline,
        payment, payment_type, stage_product, consultants_1, consulting_role_1, consultants_2, consulting_role_2,
        ho_tro, price_list_id, orgcompany_id, company_id, write_date, brand_id, brand_etl
    from {{ ref('int_sptr_transfer_inbound') }}
),

product_id_fix as (
    select clineid, brand_id, product_id as product_id_fixed
    from {{ ref('int_sptr_fix_product_id') }}
)

select
    u.id, u.product_type, u.ma_phieu, u.crm_id, u.payment_date, u.payment_method, u.communication,
    u.clineid,
    coalesce(nullif(u.product_id, 0), f.product_id_fixed) as product_id,
    u.quantity,
    case when u.uom_price is null and u.product_type = 'cosmetic' then 1 else u.uom_price end as uom_price,
    u.number_used, u.total, u.total_received, u.total_received_cline,
    u.payment, u.payment_type, u.stage_product, u.consultants_1, u.consulting_role_1, u.consultants_2, u.consulting_role_2,
    u.ho_tro, u.price_list_id, u.orgcompany_id, u.company_id, u.write_date, u.brand_id, u.brand_etl
from unioned u
left join product_id_fix f on f.clineid = u.clineid and f.brand_id = u.brand_id
