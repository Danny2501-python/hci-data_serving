{{ config(alias='mart_report_erp_source_change') }}

with sc as (
    select * from {{ ref('int_resc_source_changes') }}
),
tf as (
    select * from {{ ref('int_resc_trans_fields') }}
),
fp as (
    select * from {{ ref('int_resc_first_payment') }}
),
cl_final as (
    select * from {{ ref('stg_resc_crm_lead') }}
),
mrc_final as (
    select * from {{ ref('stg_resc_m_res_company') }}
),
rb_final as (
    select * from {{ ref('stg_resc_res_brand') }}
),

final_base as (
    select 
        sc.*,
        fp1.payment_date as payment_date_first,
        fp2.payment_date as payment_date__first_2,
        tf.crm_id, tf.booking, tf.old_data, tf.new_data, tf.stag_date_changed, tf.user_changed,
        case 
            when sc.res_id is null then rb_final_name."name"
            else sc.thuong_hieu_1
        end as thuong_hieu,
        case 
            when sc.res_id is null then mrc_final_name."name"
            else sc.chi_nhanh_1
        end as chi_nhanh
    from sc
    left join fp fp1 on fp1.crm_id = sc.res_id and fp1.brand_etl = sc.brand_etl
    full join tf on tf.crm_id = sc.res_id and tf.brand_etl = sc.brand_etl
    left join fp fp2 on fp2.crm_id = tf.crm_id and fp2.brand_etl = tf.brand_etl
    -- Joins for branches when only available in tf
    left join cl_final clf on clf.id = tf.crm_id and clf.brand_etl = tf.brand_etl
    left join mrc_final mrc_final_name on mrc_final_name.id = clf.company_id and mrc_final_name.brand_etl = clf.brand_etl
    left join rb_final rb_final_name on rb_final_name.id = mrc_final_name.brand_id and rb_final_name.brand_etl = clf.brand_etl
)

select 
    avg(payment) over (partition by crm_id, ma_phieu, product, id) as sum_payment_same_group,
    *
from final_base
