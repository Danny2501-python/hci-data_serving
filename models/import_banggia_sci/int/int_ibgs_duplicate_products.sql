select
    pricelist_id,
    product_id,
    json_agg(stt) as stt_list
from {{ ref('stg_ibgs_import_bang_gia_chi_tiet_sci') }}
group by
    pricelist_id,
    product_id
having count(*) > 1
