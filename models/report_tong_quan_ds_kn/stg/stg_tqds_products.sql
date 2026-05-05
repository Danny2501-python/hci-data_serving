select * from {{ source('tqds_crm_base', 'view_stag_products') }}
