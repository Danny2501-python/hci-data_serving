-- =============================================================================
-- stg_hqcd_product_ctg_map
-- Override kdtc_product_ctg_id cho một số nhóm dịch vụ đặc biệt
-- =============================================================================

select
    upper(product_category) as product_category,
    case
        when product_category = 'TRẺ HÓA VÙNG KÍN/NHŨ HOA' then 4
        when product_category = 'BOTOX - FILLER'             then 1
        when product_category = 'SPA KHÁC'                   then 4
        when product_category = 'PTTM KHÁC'                  then 4
        when product_category = 'PHỤ THU DỊCH VỤ'           then 1
        when product_category = 'PHỤ THU KHÁC'               then 1
        else kdtc_product_ctg_id
    end                     as kdtc_product_ctg_id
from {{ source('hqcd', 'view_stag_products') }}
where brand_etl = 1
group by 1, 2
