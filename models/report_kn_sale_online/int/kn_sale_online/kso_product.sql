select product ten_dv,
    product_id,
    product_category nhom_dv,
 sp.default_code AS id_dv,
 sp.his_service_type,
            sp.surgery_type,
            brand_etl
from {{source('kso_crm_base','view_stag_products')}} sp
where brand_etl =1