with d as (select * from {{ ref('int_ibgs_d') }}),
duplicate_products as (select * from {{ ref('int_ibgs_duplicate_products') }})

select
    idds.stt,
    idds.product_id,
    idds.pricelist_id,
    CASE
        WHEN dp.product_id IS NOT NULL THEN ' | default_code đang bị trùng stt'|| dp.stt_list
        ELSE null
    END AS false_duplicate_product_id
FROM d idds
LEFT JOIN duplicate_products dp ON idds.stt = ANY (array(select json_array_elements_text(dp.stt_list)::int))
