with source as (
    select * from {{ source('resc_crm_base', 'stag_mail_message_erp') }}
)
select * from source where type_data = 'changed_source'
