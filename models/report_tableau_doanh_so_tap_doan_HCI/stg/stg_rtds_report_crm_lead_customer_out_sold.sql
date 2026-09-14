select * from {{ source('rtds_source', 'report_crm_lead_customer_out_sold') }}
