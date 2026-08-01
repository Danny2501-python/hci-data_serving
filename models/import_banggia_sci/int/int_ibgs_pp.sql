with a as (select * from {{ ref('int_ibgs_a') }})

select stt, concat(false_id_dv, false_id_bang_gia, false_id_chi_tiet_bang_gia) as false_extenal_id
from (
    select
        a.stt,
        case
            when id_dv is null then ' | Chưa lấy được id của product_id (Cần kéo dữ liệu bảng product_product, ir_model_data về)'
            else ''
        end false_id_dv,
        case
            when a.id_chi_tiet_bang_gia is null then ' | product_id mới (chưa có trong bảng giá)'
            when a.id_chi_tiet_bang_gia is not null and not exists
                (select 1 from (select * from {{ ref('int_ibgs_ir_model_data_data') }} c where c.model = 'product.pricelist.item') l where a.id_chi_tiet_bang_gia = l.res_id) then ' | product_id cũ (Cần kéo dữ liệu bảng ir_model_data)'
            else ''
        end false_id_chi_tiet_bang_gia,
        case
            when id_bang_gia is null then ' | Bảng giá mới (Cần kéo dữ liệu bảng product_pricelist về)'
            else ''
        end false_id_bang_gia
    from a
) u
