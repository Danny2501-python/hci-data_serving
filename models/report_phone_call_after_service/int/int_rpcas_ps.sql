-- Bảng int_rpcas_ps: union bảng stg_rpcas_crm_line_info và stg_rpcas_crm_line_product_info 
SELECT * FROM {{ ref('stg_rpcas_crm_line_info')}} 

UNION ALL 

SELECT * FROM {{ ref('stg_rpcas_crm_line_product_info')}} 