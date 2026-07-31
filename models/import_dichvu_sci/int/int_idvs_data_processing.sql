with input_data as (select * from {{ ref('int_idvs_input_data') }}),
system_data as (select * from {{ ref('int_idvs_system_data') }})

select
            idds.stt,
            idds.id,
            idds."default_code cũ",
            idds."default_code mới",
            case
                when idds."name" is null then a."name"
                else idds."name"
            end as "name",
            case
                when idds."service_category/name" is null then a."service_category/name"
                else idds."service_category/name"
            end as "service_category/name",
            idds."service_category/id",
            idds."institution/id",
            idds."service_department/id",
            idds."service_room/id",
            idds."exam_room/id",
            idds."categ_id/id",
            case
                when idds.type_product_crm is null then a.type_product_crm
                else idds.type_product_crm
            end as "type_product_crm",
            trim(idds.list_price::text, '.') as list_price,
            trim(price_min::text, '.') as price_min,
            case
                when idds."currency_id/id" is null then a."currency_id/id"
                else idds."currency_id/id"
            end as "currency_id/id",
            case
                when idds.is_surgeries::text is null then a.is_surgeries
                else idds.is_surgeries::text
            end as is_surgeries,
            idds.surgery_type,
            idds.anesthetist_type,
            case
                when idds."uom_id/id" is null then a."uom_id/id"::text
                else idds."uom_id/id"
            end as "uom_id/id",
            case
                when idds."uom_id/name" is null then a."uom_id/name"
                else idds."uom_id/name"
            end as "uom_id/name",
            case
                when idds."uom_so_id/id" is null then a."uom_so_id/id"::text
                else idds."uom_so_id/id"
            end as "uom_so_id/id",
            case
                when idds."uom_po_id/id" is null then a."uom_po_id/id"::text
                else idds."uom_po_id/id"
            end as "uom_po_id/id",
            case
                when idds.his_service_type is null then a.his_service_type
                else idds.his_service_type
            end as his_service_type,
            case
                when idds.level_of_difficult is null then a.level_of_difficult::text
                else idds.level_of_difficult::text
            end as level_of_difficult,
            case
                when idds.execution_time is null then a.execution_time
                else idds.execution_time
            end as execution_time,
            case
                when idds.recovery_time is null then a.recovery_time::text
                else idds.recovery_time
            end as recovery_time,
            case
                when idds.warranty_period is null then a.warranty_period
                else idds.warranty_period
            end as warranty_period,
            case
                when idds."uom_guarantee/name" is null then a."uom_guarantee/name"
                else idds."uom_guarantee/name"
            end as "uom_guarantee/name",
            case
                when idds.note is null then a.note
                else idds.note
            end as note,
            case
                when idds.kpi_point is null then a.kpi_point::text
                else idds.kpi_point::text
            end as kpi_point,
            case
                when idds.kpi_point_num is null then a.kpi_point_num::text
                else idds.kpi_point_num::text
            end as kpi_point_num,
            case
                when idds.is_no_specialty::text is null then a.is_no_specialty
                else idds.is_no_specialty::text
            end as is_no_specialty,
            case
                when idds.is_no_phonecall::text is null then a.is_no_phonecall
                else idds.is_no_phonecall::text
            end as is_no_phonecall,
            case
                when idds.is_input_num::text is null then a.is_input_num
                else idds.is_input_num::text
            end as is_input_num,
            case
                when idds."lab_type_ids/id" is not null then lab_type_ids.lab_id
                else idds."lab_type_ids/id"
            end as "lab_type_ids/id",
            case
                when idds."imaging_type_ids/id" is not null then imaging_type_ids.image_id
                else idds."imaging_type_ids/id"
            end as "imaging_type_ids/id",
            idds."ceiling_discount_ids/brand_id/id",
            case
                when idds."ceiling_discount_ids/ceiling_discount" is null then a."ceiling_discount_ids/ceiling_discount"::text
                else idds."ceiling_discount_ids/ceiling_discount"::text
            end "ceiling_discount_ids/ceiling_discount",
            case
                when idds."hướng dẫn sau dịch vụ" is null then a."hướng dẫn sau dịch vụ"
                else idds."hướng dẫn sau dịch vụ"
            end as "hướng dẫn sau dịch vụ",
            case
                when idds."tính hoa hồng ctv" is null then a."tính hoa hồng ctv"
                else idds."tính hoa hồng ctv"
            end as "tính hoa hồng ctv",
            idds."ghi_chu",
            idds.brand
        from
            input_data idds
        left join system_data a on
            a."default_code cũ"= idds."default_code cũ" and idds.brand = a.brand_etl
        left join (with a as (
            with inputs as (
            select "default_code cũ", brand, unnest(string_to_array("imaging_type_ids/id",',')) as unnest_image_id from {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} idds
            )
            select a.*, smitt.id, concat(imd."module",'.',imd.name) as image_id from inputs a
            left join {{ ref('stg_idvs_product_product') }} pp on pp.default_code = a.unnest_image_id and a.brand = pp.brand_etl
            left join {{ ref('stg_idvs_sh_medical_imaging_test_type') }} smitt on pp.id = smitt.product_id and pp.brand_etl = smitt.brand_etl
            left join (select * from {{ ref('stg_idvs_ir_model_data') }} imd where imd.model = 'sh.medical.imaging.test.type') imd on imd.res_id = smitt.id
            )
            select "default_code cũ",brand,string_agg(image_id, ',') as image_id from a group by "default_code cũ", brand) imaging_type_ids
            on imaging_type_ids."default_code cũ" = idds."default_code cũ" and imaging_type_ids.brand = idds.brand
        left join (
            with a as (
            with inputs as (
            select "default_code cũ", brand, unnest(string_to_array(trim("lab_type_ids/id"),',')) as unnest_lab_id from {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} idds
            )
            select a.*, smlt.id, concat(imd."module",'.',imd.name) as lab_id from inputs a
            left join {{ ref('stg_idvs_product_product') }} pp on pp.default_code = trim(a.unnest_lab_id) and pp.brand_etl = a.brand
            left join {{ ref('stg_idvs_sh_medical_labtest_types') }} smlt on pp.id = smlt.product_id and pp.brand_etl = smlt.brand_etl
            left join (select * from {{ ref('stg_idvs_ir_model_data') }} imd where imd.model = 'sh.medical.labtest.types') imd on imd.res_id = smlt.id and imd.brand_etl = smlt.brand_etl
            )
            select "default_code cũ",brand ,string_agg(lab_id, ',') as lab_id from a group by "default_code cũ", brand) lab_type_ids
            on lab_type_ids."default_code cũ" = idds."default_code cũ" and lab_type_ids.brand = idds.brand
        order by  idds.stt
