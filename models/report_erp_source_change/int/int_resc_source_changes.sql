with mcsc_base as (
    select * from {{ ref('stg_resc_mail_message') }}
),
employees as (
    select * from {{ ref('int_resc_employees_matched') }}
),
crm_lead as (
    select * from {{ ref('stg_resc_crm_lead') }}
),
sources as (
    select * from {{ ref('stg_resc_sources') }}
),
leads_with_opp as (
    select * from {{ ref('int_resc_leads_filtered') }}
),
payment_transfer as (
    select * from {{ ref('int_resc_payment_transfer_base') }}
),

mcsc_with_emp as (
    select
        mcsc.*,
        se.employee as name_changed,
        se.employee_code,
        se.department
    from mcsc_base mcsc
    left join employees se on 
        (mcsc.brand_etl = 1 and se.kn_user_id = mcsc.write_uid) or 
        (mcsc.brand_etl = 3 and se.pr_user_id = mcsc.write_uid) or
        (mcsc.brand_etl = 0 and se.old_user_id = mcsc.write_uid)
)

select
    mcsc.id, mcsc.old_value_char, mcsc.new_value_char, mcsc.date_changed,
    mcsc.res_id, mcsc.write_uid, mcsc.brand_etl, mcsc.status_bk,
    mcsc.name_changed, mcsc.employee_code, mcsc.department,
    cl."name", cl."type", cl.contact_name, cl.phone,
    cl.create_on + interval '7 hours' as create_date_book,
    rb."name" as thuong_hieu_1,
    mrc."name" as chi_nhanh_1,
    -- Payment info
    spt.id as payment_id, spt.payment, spt.payment_date, spt.ma_phieu,
    spt.product, spt.company_ds, spt.brand_ds, spt.communication,
    -- Source names
    case when cl.brand_id = 3 then ss12.category_source_code else ss11.category_source_code end as category_source_name_old,
    case when cl.brand_id = 3 then ss22.category_source_code else ss21.category_source_code end as category_source_name_new
from mcsc_with_emp mcsc
left join crm_lead cl on cl.id = mcsc.res_id and cl.brand_etl = mcsc.brand_etl
left join sources ss11 on ss11.old_id = mcsc.old_value_integer
left join sources ss12 on ss12.old_id = ss11.id_pr
left join sources ss21 on ss21.old_id = mcsc.new_value_integer
left join sources ss22 on ss22.old_id = ss21.id_pr
left join {{ ref('stg_resc_m_res_company') }} mrc on mrc.id = cl.company_id and mrc.brand_etl = cl.brand_etl
left join {{ ref('stg_resc_res_brand') }} rb on rb.id = mrc.brand_id and rb.brand_etl = mrc.brand_etl
left join payment_transfer spt on spt.crm_id = mcsc.res_id and spt.brand_etl = mcsc.brand_etl
where not exists (
    select 1 from leads_with_opp lwo 
    where lwo.id = cl.id and lwo.brand_etl = cl.brand_etl
)
