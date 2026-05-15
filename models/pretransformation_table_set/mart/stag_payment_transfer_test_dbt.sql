{{
    config(
        materialized = 'incremental',
        unique_key = ['crm_id','brand_etl'],
        incremental_strategy = 'delete+insert',
        alias = 'stag_payment_transfer_test_dbt'
    )
}}
-- Bảng stag_payment_transfer_test_dbt: Tổng hợp các giao dịch chuyển tiền ra vào chi nhánh, điều chuyển giữa các chi nhánh
WITH pre_final AS (
    SELECT 
        spa.id::varchar,
        spa.product_type::varchar,
        spa.ma_phieu::varchar,
        spa.crm_id::int,
        spa.payment_date::date,
        spa.payment_method::varchar,
        spa.communication::varchar,
        spa.clineid::int,
        spa.product_id::int,
        spa.quantity::int,
        spa.uom_price::float8,
        spa.number_used::int,
        spa.total::numeric,
        spa.total_received::numeric,
        spa.total_received_cline::numeric,
        spa.payment::numeric,
        spa.payment_type::varchar,
        spa.stage_product::varchar,
        spa.consultants_1::int,
        spa.consulting_role_1::varchar,
        spa.consultants_2::int,
        spa.consulting_role_2::varchar,
        spa.ho_tro::int,
        spa.price_list_id::int,
        spa.orgcompany_id::int,
        spa.company_id::int,
        spa.write_date::timestamp,
        spa.brand_id::int,
        spa.brand_etl::int,
        spa.first_date_payment::date,
        spa.rnk_crm_pmdate::int,
        spa.rnk_clineid_pmdate::int,
        spa.rnk_clineid_pmdate_desc::int,
        CASE 
            WHEN ROUND(spa.total_received_cumsum,0) = ROUND(spa.total + spa.total_received_old,0) 
                OR ROUND(spa.total,0) = ROUND(spa.total_received + spa.payment,0) THEN spa.total::numeric
            WHEN ROUND(spa.payment + spa.total_received,0) > ROUND(spa.total,0) THEN (spa.total_received + spa.payment)::numeric
            ELSE spa.total_received_cumsum::numeric
        END AS total_received_cumsum,
        spa.total_received_old::numeric,
        spa.is_priority::int
    FROM {{ref('int_pts_stag_payment_all')}} spa
)
SELECT 
    pf.*,
    LAST_VALUE(pf.total_received_cumsum) OVER (
        PARTITION BY pf.brand_etl,pf.crm_id,pf.clineid,pf.product_id,pf.payment_date
        ORDER BY pf.payment_date ASC,pf.is_priority DESC,pf.write_date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )::numeric AS total_received_recal,
    CONCAT(pf.id,'-',pf.brand_etl)::text AS global_id
FROM pre_final pf