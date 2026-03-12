{{ config(materialized='table') }}

with product_base as (
    select
        smhcs.id as smhcsid,
        coalesce(smhcs.his_service_type, case when pp.default_code like 'TDL%' then 'Card' end) as his_service_type,
        smhcs.surgery_type,
        smhcsc.product_cat_id as product_ctg_id,
        smhcs.kpi_first_time,
        trim(coalesce(
            regexp_replace(pc.name, '\s+', ' ', 'g'),
            case 
                when smhcs.his_service_type is not null then 'PTTM KHÁC' 
                when pp.default_code like 'TDL%' then 'THẺ DA LIỄU' 
                else 'SAN PHAM' 
            end
        )) as product_category,
        pimp.product_category_paris,
        pimp.product_category_new,
        pp.id as product_id,
        pp.default_code,
        trim(pt.name) as product,
        pt.list_price,
        pimp.is_main_service,
        pimp.group_id,
        pimp.product_id_kn,
        pimp.is_vip,
        pimp.qty_service,
        case when smhcs.kpi_point = 0 then null else smhcs.kpi_point end as kpi_point_raw,
        case when smhcs.kpi_point_num = 0 then 1 else coalesce(smhcs.kpi_point_num, 1) end as kpi_point_num,
        pt.uom_id,
        uu.name as uom,
        pp.create_date,
        greatest(pp.write_date, smhcs.write_date) as write_date,
        case 
            when pp.default_code like 'TDL%' then 1 
            when coalesce(pc.name, smhcs.his_service_type) is null or pc.name ~* 'TPM' then null 
            when pc.name ~* 'pttm.*mắt' then 3 
            when pc.name ~* 'pttm.*mũi' then 8
            when pc.name ~* 'ngực|mông' then 5
            when pc.name ~* '(pttm.*mỡ)|hút mỡ' then 6
            when pc.name ~* 'hàm mặt' then 7
            when pc.name ~* 'gội đầu|dưỡng sinh|phun xăm|triệt lô|tắm trắ' or pc.name = 'ĐIỀU TRỊ MỤN' then 2
            when pc.name ~* 'căng (chỉ|da)' then 4
            when smhcs.his_service_type in ('Laser', 'Spa') then 1
            else 4
        end as kdtc_product_ctg_id,
        pp.brand_etl
    from {{ source('erp', 'product_product') }} pp
    left join {{ source('erp', 'sh_medical_health_center_service') }} smhcs 
        on smhcs.product_id = pp.id and smhcs.brand_etl = pp.brand_etl
    left join {{ source('erp', 'sh_medical_health_center_service_category') }} smhcsc 
        on smhcs.service_category = smhcsc.id and smhcs.brand_etl = smhcsc.brand_etl
    left join {{ source('erp', 'product_category') }} pc 
        on smhcsc.product_cat_id = pc.id and smhcs.brand_etl = pc.brand_etl
    left join {{ source('erp', 'product_template') }} pt 
        on pp.product_tmpl_id = pt.id and pp.brand_etl = pt.brand_etl
    left join {{ source('erp', 'uom_uom') }} uu 
        on pt.uom_id = uu.id and uu.brand_etl = pt.brand_etl
    left join (
        select * from {{ source('erp', 'import_product_service_analyst') }}
        where product_category <> 'SAN PHAM'
    ) pimp on (case when pp.brand_etl < 2 then pp.id end) = pimp.product_id
),

final_calc as (
    select
        *,
        -- Logic is_no_kpi
        case 
            when product_id in (10801,8207,8194,10252,10254,10255,10716,16836,17097,20306,20881,20890,20090,20290,20279,20280,20282) 
            then 'True' else '' 
        end as is_no_kpi,
        
        -- Logic gr_bh_id (Bảo hành)
        case
            when product_ctg_id in (411,454,1334,1336,1394) or product ~* 'tàn nhang|nám|ban vàng|chàm|u tuyến bã|trị.*đồi mồi|bớt (sùi)?' then 2
            when product_ctg_id in (419,466,1345,1396) or product ~* 'mụn (thịt|cơm)|tẩy nốt ruồi' then 3
            when product_ctg_id in (424,425,475,485,1344,1361,426,1302,1351) or product ~* 'xóa (hình )?xăm|phun (môi|mày|mí|thêu)|điêu khắc|hair stro' then 4
            when product_ctg_id in (428,484,1350) or product ~* 'triệt (lông|râu|ria)' then 5
            when product ~* '(botox|botul|(nhăn|mặt).*aller).*' then 6
            when his_service_type in ('Laser', 'Spa') then 1
            else null
        end as gr_bh_id
    from product_base
)

select * from final_calc
