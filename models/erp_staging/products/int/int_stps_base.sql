-- Tương đương query_pd trong quentk_1_stag_crm_New_sys_v2.py, gộp 5 brand (kn/pr/hh/thv/sci) trong 1 lượt quét
-- thay vì chạy lại query 5 lần với brand_etl khác nhau như bản Python.
with pimp as (
    select *
    from {{ ref('stg_stps_import_product_service_analyst') }}
    where product_category <> 'SAN PHAM'
)

select
    smhcs.id as smhcsid
    , coalesce(smhcs.his_service_type, case when pp.default_code like 'TDL%' then 'Card' end) as his_service_type
    , smhcs.surgery_type
    , smhcsc.product_cat_id as product_ctg_id
    , smhcs.kpi_first_time
    , trim(coalesce(
        regexp_replace(pc.name, '\s+', ' ', 'g')
        , case when smhcs.his_service_type is not null then 'PTTM KHÁC'
            when pp.default_code like 'TDL%' then 'THẺ DA LIỄU'
            else 'SAN PHAM' end)) as product_category
    , pimp.product_category_paris, pimp.product_category_new
    , pp.id as product_id, pp.default_code, trim(pt.name) as product, pt.list_price, pp.product_tmpl_id
    , pimp.is_main_service, pimp.group_id::int as group_id, pimp.product_id_kn, pimp.is_vip, pimp.qty_service
    , case when smhcs.kpi_point = 0 then null else smhcs.kpi_point end as kpi_point
    , case when smhcs.kpi_point_num = 0 then 1 else coalesce(smhcs.kpi_point_num, 1) end as kpi_point_num
    , pt.uom_id, uu.name as uom
    , pp.create_date, greatest(pp.write_date, smhcs.write_date) as write_date
    , case when pp.default_code like 'TDL%' then 1
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
    end as kdtc_product_ctg_id
    , pp.brand_etl
    , case pp.brand_etl when 1 then 'kn' when 3 then 'pr' when 4 then 'hh' when 8 then 'thv' when 7 then 'sci' end as br
from {{ ref('stg_stps_product_product') }} pp
left join {{ ref('stg_stps_sh_medical_health_center_service') }} smhcs
    on smhcs.product_id = pp.id and smhcs.brand_etl = pp.brand_etl
left join {{ ref('stg_stps_sh_medical_health_center_service_category') }} smhcsc
    on smhcs.service_category = smhcsc.id and smhcs.brand_etl = smhcsc.brand_etl
left join {{ ref('stg_stps_product_category') }} pc
    on smhcsc.product_cat_id = pc.id and smhcs.brand_etl = pc.brand_etl
left join {{ ref('stg_stps_product_template') }} pt
    on pp.product_tmpl_id = pt.id and pp.brand_etl = pt.brand_etl
left join {{ ref('stg_stps_uom_uom') }} uu
    on pt.uom_id = uu.id and uu.brand_etl = pt.brand_etl
left join pimp
    on (case when pp.brand_etl < 2 then pp.id end) = pimp.product_id
where pp.brand_etl in (1, 3, 4, 8, 7)
