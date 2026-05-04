select * from {{ source('resc_crm_base', 'stag_employees') }}
