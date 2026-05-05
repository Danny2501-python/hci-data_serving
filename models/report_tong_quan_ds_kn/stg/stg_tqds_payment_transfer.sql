select * from {{ source('tqds_crm_base', 'stag_payment_transfer') }}
