select
    res_id,
    name,
    "module",
    model,
    date_update,
    brand_etl
from {{ ref('stg_ibgs_ir_model_data') }}
where model in ('product.pricelist.item', 'product.pricelist', 'product.product')
