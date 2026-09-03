-- Tương ứng CTE `type_data_nhomdichvu` trong Readme.md.
-- output_data được ref lại 2 lần (trực tiếp làm `nd` + trong subquery `f`) - xem LOGIC.md
-- mục "Vì sao int là table" để biết lý do int materialize table thay vì ephemeral.
with output_data as (
    select * from {{ ref('int_indvs_output_data') }}
),
note_data as (
    select * from {{ ref('int_indvs_note_data') }}
),
res_brand as (
    select * from {{ ref('stg_indvs_res_brand') }}
)

select nd.*,
    case
        when a.is_prod_cat_new is null then 'Error: Không nhập Code cho nhóm dịch vụ'
        when a.is_prod_cat_new is false then 'Nhóm dịch vụ cũ'|| false_id || f.false_prod_cat_duplicate || f.false_brand_id
        else 'Nhóm dịch vụ mới' || false_id || f.false_name || f.false_product_cat_id || f.false_brand_id
    end as data_status
from
    output_data nd
left join (
    select
        nd.code,
        case
            when nd.id is null then ' | thiếu id cho nhóm dịch vụ'
            else ''
        end as false_id,
        case
            when nd."name" is null then ' | thiếu tên nhóm dịch vụ'
            else ''
        end as false_name,
        case
            when nd."product_cat_id/name" is null then ' | thiếu product_cat_id/name'
            else ''
        end as false_product_cat_id,
        case
            when not exists (select 1 from res_brand rb where nd."brand_id/name" = rb."name") then ' | Sai tên "brand_id/name"'
            else ''
        end false_brand_id,
        case
            when nd.is_prod_cat_duplicate is true then ' | Dữ liệu đang bị có 2 nhóm dịch vụ'
            else ''
        end as false_prod_cat_duplicate
    from
        output_data nd ) f on
    nd.code = f.code
left join note_data a on a.code = nd.code
