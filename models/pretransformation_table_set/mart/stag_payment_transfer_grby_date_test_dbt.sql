{{
    config(
        materialized = 'incremental',
        unique_key = ['crm_id','brand_etl'],
        incremental_strategy = 'delete+insert',
        alias = 'stag_payment_transfer_grby_date_test_dbt'
    )
}}
WITH agg_data AS (
    SELECT 
        st.brand_id,
        st.crm_id,
        st.product_id,
        st.payment_date,
        STRING_AGG(st.id::text, ',')::text as id,
        STRING_AGG(st.ma_phieu::text, ',')::text as ma_phieu,
        STRING_AGG(st.clineid::text,',')::text as clineid,
        STRING_AGG(st.payment_type::text,',')::text as payment_type,
        SUM(st.payment::FLOAT) as payment
    FROM {{ref('stag_payment_transfer_test_dbt')}} st
    GROUP BY 1,2,3,4
),
-- 2. Xử lý nhóm dflast (Lấy giá trị của dòng cuối cùng trong nhóm)
last_data AS (
    -- DISTINCT ON sẽ giữ lại chính xác 1 dòng đầu tiên cho mỗi nhóm
    SELECT DISTINCT ON (st.brand_id, st.crm_id, st.product_id, st.payment_date)
        st.* 
    FROM {{ref('stag_payment_transfer_test_dbt')}} st
    ORDER BY 
        st.brand_id, st.crm_id, st.product_id, st.payment_date, st.clineid,
        st.is_priority DESC,
        st.write_date
)
SELECT 
    ad.brand_id, 
    ad.crm_id, 
    ad.product_id, 
    ad.payment_date,
    ad.id, 
    ad.ma_phieu, 
    ad.clineid, 
    ad.payment_type, 
    ad.payment,
    ld.quantity, 
    ld.uom_price, 
    ld.number_used, 
    ld.total, 
    ld.total_received, 
    ld.total_received_recal, 
    ld.stage_product, 
    ld.consultants_1, 
    ld.consulting_role_1, 
    ld.consultants_2, 
    ld.consulting_role_2, 
    ld.price_list_id, 
    ld.orgcompany_id, 
    ld.company_id, 
    ld.brand_etl
FROM agg_data ad
    JOIN last_data ld 
        ON ad.brand_id = ld.brand_id 
        AND ad.crm_id = ld.crm_id 
        AND ad.product_id = ld.product_id 
        AND ad.payment_date = ld.payment_date