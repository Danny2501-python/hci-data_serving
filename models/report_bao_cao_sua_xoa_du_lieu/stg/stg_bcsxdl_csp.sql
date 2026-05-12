with a as (
    select 
        'deleted_data' as type_data, 
        lcsp.id,
        lcsp.name,
        lcsp.booking_id,
        lcsp.transfer_payment_id,
        lcsp.account_payment_id,
        lcsp.account_payment_detail_id,
        lcsp.account_payment_product_detail_id,
        lcsp.crm_line_id,
        lcsp.crm_line_product_id,
        lcsp.product_category_id,
        lcsp.product_type,
        lcsp.product_id,
        lcsp.service_id,
        lcsp.kpi_point,
        lcsp.payment_type,
        lcsp.amount_proceeds,
        lcsp.currency_id,
        lcsp.is_deposit,
        lcsp.partner_id,
        lcsp.user_id,
        lcsp.company_id,
        lcsp.category_source_id,
        lcsp.create_date,
        lcsp.communication,
        lcsp.over_discount,
        lcsp.create_uid,
        lcsp.write_uid,
        lcsp.write_date,
        lcsp.service_category,
        lcsp.remaining_amount,
        lcsp.payment_date,
        lcsp.not_sale,
        lcsp.transfer_payment_line_id,
        lcsp.transaction_company_id,
        lcsp.internal_payment_type,
        lcsp.department,
        lcsp.consultants_1,
        lcsp.consulting_role_1,
        lcsp.consultants_2,
        lcsp.consulting_role_2,
        lcsp.payment_method,
        lcsp.khong_tinh_doanh_so,
        null::int as partner_debt_id,
        null::date as snapshot_date,
        null::timestamp as ingestion_timestamp,
        null::text as source_server,
        lcsp.brand_etl
    from {{ source('bao_cao_sua_xoa_du_lieu', 'log_crm_sale_payment') }} lcsp 
    union all
    select 
        'existing_data' as type_data, 
        csp.id,
        csp.name,
        csp.booking_id,
        csp.transfer_payment_id,
        csp.account_payment_id,
        csp.account_payment_detail_id,
        csp.account_payment_product_detail_id,
        csp.crm_line_id,
        csp.crm_line_product_id,
        csp.product_category_id,
        csp.product_type,
        csp.product_id,
        csp.service_id,
        csp.kpi_point,
        csp.payment_type,
        csp.amount_proceeds,
        csp.currency_id,
        csp.is_deposit,
        csp.partner_id,
        csp.user_id,
        csp.company_id,
        csp.category_source_id,
        csp.create_date,
        csp.communication,
        csp.over_discount,
        csp.create_uid,
        csp.write_uid,
        csp.write_date,
        csp.service_category,
        csp.remaining_amount,
        csp.payment_date,
        csp.not_sale,
        csp.transfer_payment_line_id,
        csp.transaction_company_id,
        csp.internal_payment_type,
        csp.department,
        csp.consultants_1,
        csp.consulting_role_1,
        csp.consultants_2,
        csp.consulting_role_2,
        csp.payment_method,
        csp.khong_tinh_doanh_so,
        csp.partner_debt_id,
        csp.snapshot_date,
        csp.ingestion_timestamp,
        csp.source_server,
        csp.brand_etl 
    from {{ source('bao_cao_sua_xoa_du_lieu', 'crm_sale_payment') }} csp
    where exists (
        select 1 
        from {{ source('bao_cao_sua_xoa_du_lieu', 'log_crm_sale_payment') }} lcsp 
        where lcsp.booking_id = csp.booking_id
    )
),
comparison as (
    select 
        e.id as existing_id,
        d.create_date as deleted_create_date,
        e.create_date as existing_create_date
    from a d
    join a e
    on d.booking_id = e.booking_id
    where d.type_data = 'deleted_data' and e.type_data = 'existing_data'
)
select 
    a.*, 
    case 
        when c.deleted_create_date > c.existing_create_date then true
        when c.existing_id is null then true  
        else false
    end as is_data_before_deleted
from a
left join comparison c 
    on a.id = c.existing_id