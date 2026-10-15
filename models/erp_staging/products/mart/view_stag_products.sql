{{ config(alias='view_stag_products', materialized='view') }}

-- Port 1:1 từ public.view_stag_products (view thủ công hiện có trong DB new_product,
-- không thuộc quản lý của dbt) sang model dbt, chạy SAU KHI mart/stag_products.sql
-- (bảng stag_products) build xong nhờ ref() bên dưới -- dbt tự xếp thứ tự theo lineage.
-- Giữ nguyên cấu trúc UNION ALL theo brand_etl (0=sci, 1=kn, 2=da, 3=pr, 4=hh, 8=thv — 2=Đông Á thêm 2026-10-14) và các
-- cột dùng CHUNG cho mọi nhánh (service_id <- smhcsid, product_ctg_id) đúng như view gốc --
-- KHÔNG đổi sang các cột theo từng brand (pr_smhcsid/hh_smhcsid/.../pr_product_ctg_id/...)
-- dù bảng stag_products có sẵn các cột đó, để tránh lệch hành vi so với view đang chạy thật.
with dm_sp as (

    select
        sp.smhcsid as service_id,
        sp.sci_product_id as product_id,
        sp.product_ctg_id,
        sp.default_code,
        sp.his_service_type,
        sp.surgery_type,
        sp.product_category,
        sp.product,
        sp.list_price,
        sp.group_id,
        sp.kpi_point,
        sp.kpi_point_num,
        sp.kpi_first_time,
        sp.uom_id,
        sp.uom,
        sp.qty_service,
        sp.gr_bh_id,
        sp.kdtc_product_ctg_id,
        sp.is_no_kpi,
        sp.is_main_service,
        sp.create_date,
        sp.write_date,
        0 as brand_etl
    from {{ ref('stag_products') }} sp
    where sp.sci_product_id is not null

    union all

    select
        sp.smhcsid as service_id,
        sp.product_id,
        sp.product_ctg_id,
        sp.default_code,
        sp.his_service_type,
        sp.surgery_type,
        sp.product_category,
        sp.product,
        sp.list_price,
        sp.group_id,
        sp.kpi_point,
        sp.kpi_point_num,
        sp.kpi_first_time,
        sp.uom_id,
        sp.uom,
        sp.qty_service,
        sp.gr_bh_id,
        sp.kdtc_product_ctg_id,
        sp.is_no_kpi,
        sp.is_main_service,
        sp.create_date,
        sp.write_date,
        1 as brand_etl
    from {{ ref('stag_products') }} sp
    where sp.product_id is not null

    union all

    select
        sp.smhcsid as service_id,
        sp.pr_product_id as product_id,
        sp.product_ctg_id,
        sp.default_code,
        sp.his_service_type,
        sp.surgery_type,
        coalesce(pc.name, sp.product_category) as product_category,
        pt.name as product,
        sp.list_price,
        sp.group_id,
        sp.kpi_point,
        sp.kpi_point_num,
        sp.kpi_first_time,
        sp.uom_id,
        sp.uom,
        sp.qty_service,
        sp.gr_bh_id,
        sp.kdtc_product_ctg_id,
        sp.is_no_kpi,
        sp.is_main_service,
        sp.create_date,
        sp.write_date,
        3 as brand_etl
    from {{ ref('stag_products') }} sp
    left join {{ ref('stg_stps_product_template') }} pt
        on sp.pr_product_tmpl_id = pt.id and pt.brand_etl = 3
    left join {{ ref('stg_stps_product_category') }} pc
        on sp.pr_product_ctg_id = pc.id and pc.brand_etl = 3
    where sp.pr_product_id is not null

    union all

    select
        sp.smhcsid as service_id,
        sp.hh_product_id as product_id,
        sp.product_ctg_id,
        sp.default_code,
        sp.his_service_type,
        sp.surgery_type,
        coalesce(pc.name, sp.product_category) as product_category,
        pt.name as product,
        sp.list_price,
        sp.group_id,
        sp.kpi_point,
        sp.kpi_point_num,
        sp.kpi_first_time,
        sp.uom_id,
        sp.uom,
        sp.qty_service,
        sp.gr_bh_id,
        sp.kdtc_product_ctg_id,
        sp.is_no_kpi,
        sp.is_main_service,
        sp.create_date,
        sp.write_date,
        4 as brand_etl
    from {{ ref('stag_products') }} sp
    left join {{ ref('stg_stps_product_template') }} pt
        on sp.hh_product_tmpl_id = pt.id and pt.brand_etl = 4
    left join {{ ref('stg_stps_product_category') }} pc
        on sp.hh_product_ctg_id = pc.id and pc.brand_etl = 4
    where sp.hh_product_id is not null

    union all

    select
        sp.smhcsid as service_id,
        sp.thv_product_id as product_id,
        sp.product_ctg_id,
        sp.default_code,
        sp.his_service_type,
        sp.surgery_type,
        coalesce(pc.name, sp.product_category) as product_category,
        pt.name as product,
        sp.list_price,
        sp.group_id,
        sp.kpi_point,
        sp.kpi_point_num,
        sp.kpi_first_time,
        sp.uom_id,
        sp.uom,
        sp.qty_service,
        sp.gr_bh_id,
        sp.kdtc_product_ctg_id,
        sp.is_no_kpi,
        sp.is_main_service,
        sp.create_date,
        sp.write_date,
        8 as brand_etl
    from {{ ref('stag_products') }} sp
    left join {{ ref('stg_stps_product_template') }} pt
        on sp.thv_product_tmpl_id = pt.id and pt.brand_etl = 8
    left join {{ ref('stg_stps_product_category') }} pc
        on sp.thv_product_ctg_id = pc.id and pc.brand_etl = 8
    where sp.thv_product_id is not null

    union all

    select
        sp.smhcsid as service_id,
        sp.da_product_id as product_id,
        sp.product_ctg_id,
        sp.default_code,
        sp.his_service_type,
        sp.surgery_type,
        coalesce(pc.name, sp.product_category) as product_category,
        pt.name as product,
        sp.list_price,
        sp.group_id,
        sp.kpi_point,
        sp.kpi_point_num,
        sp.kpi_first_time,
        sp.uom_id,
        sp.uom,
        sp.qty_service,
        sp.gr_bh_id,
        sp.kdtc_product_ctg_id,
        sp.is_no_kpi,
        sp.is_main_service,
        sp.create_date,
        sp.write_date,
        2 as brand_etl
    from {{ ref('stag_products') }} sp
    left join {{ ref('stg_stps_product_template') }} pt
        on sp.da_product_tmpl_id = pt.id and pt.brand_etl = 2
    left join {{ ref('stg_stps_product_category') }} pc
        on sp.da_product_ctg_id = pc.id and pc.brand_etl = 2
    where sp.da_product_id is not null

)

select
    dm_sp.service_id,
    dm_sp.product_id,
    dm_sp.product_ctg_id,
    dm_sp.default_code,
    dm_sp.his_service_type,
    dm_sp.surgery_type,
    dm_sp.product_category,
    dm_sp.product,
    dm_sp.list_price,
    dm_sp.group_id,
    dm_sp.kpi_point,
    dm_sp.kpi_point_num,
    dm_sp.kpi_first_time,
    dm_sp.uom_id,
    dm_sp.uom,
    dm_sp.qty_service,
    dm_sp.gr_bh_id,
    dm_sp.kdtc_product_ctg_id,
    dm_sp.is_no_kpi,
    dm_sp.is_main_service,
    dm_sp.create_date,
    dm_sp.write_date,
    dm_sp.brand_etl,
    case
        when dm_sp.product_category = 'SAN PHAM' then 'SẢN PHẨM'
        -- [Sửa — xem README.md] Đặt TRƯỚC nhánh BEAUTY & SPA: riêng category
        -- 'GIẢM BÉO KHÔNG PT' có his_service_type = 'Laser'/'Spa' (không phải
        -- 'weight_loss' — khác với 3 nhóm "Giảm béo Dịch vụ lẻ"/MetaKid/Metacore,
        -- 3 nhóm đó có his_service_type='weight_loss' thật, khớp ngay điều kiện đầu
        -- của nhánh này, KHÔNG phụ thuộc thứ tự CASE). Vì 'GIẢM BÉO KHÔNG PT' trùng
        -- đúng điều kiện nhánh Spa/Laser/Card phía dưới, nếu để nhánh này đứng SAU như
        -- cũ, CASE WHEN khớp nhánh đầu tiên rồi dừng — 'GIẢM BÉO KHÔNG PT' sẽ luôn bị
        -- bắt nhầm vào 'BEAUTY & SPA', điều kiện vừa thêm không bao giờ được xét tới.
        when dm_sp.his_service_type = 'weight_loss'
            OR (dm_sp.his_service_type = 'Surgery' and dm_sp.product_category ~* 'HÚT MỠ')
            OR (dm_sp.product_category = 'GIẢM BÉO KHÔNG PT') then 'BÉO ĐA CHUYÊN KHOA'
        when dm_sp.his_service_type in ('Spa', 'Laser', 'Card') then 'BEAUTY & SPA'
        when dm_sp.his_service_type = 'Odontology' then 'DỊCH VỤ KHÁC'
        when  dm_sp.product_category ~* 'HÀM MẶT' then 'PTTM HÀM MẶT'
        when dm_sp.his_service_type = 'wellness' then 'WELLNESS'
        when dm_sp.product_category ~* 'MẮT' then 'PTTM MẮT'
        when dm_sp.product_category ~* 'MŨI' then 'PTTM MŨI'
        when dm_sp.product_category ~* 'CẤY MỠ' then 'CẤY MỠ'
        when dm_sp.product_category ~* 'NGỰC|MÔNG' then 'PTTM NGỰC/MÔNG'
        else 'DỊCH VỤ KHÁC'
    end as product_group
from dm_sp
