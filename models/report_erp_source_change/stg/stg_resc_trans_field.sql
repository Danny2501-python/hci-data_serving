with source as (
    select * from {{ source('resc_crm_base', 'view_ks_crm_lead_trans_field') }}
)
select * from source where type_data = 'source'
