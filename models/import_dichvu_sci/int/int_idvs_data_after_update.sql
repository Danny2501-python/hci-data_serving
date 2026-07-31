with update_id_new_code as (select * from {{ ref('int_idvs_update_id_new_code') }})

select
            oss.stt,
            oss.id,
            oss.default_code,
            oss.name,
            oss."service_category/name",
            oss."service_category/id",
            case
                when oss."institution/id" is null then isbr."institution/id"
                else oss."institution/id"
            end as "institution/id",
            case
                when oss."service_department/id" is null then isbr."service_department/id"
                else oss."service_department/id"
            end as "service_department/id",
            case
                when oss."service_room/id" is null then isbr."service_room/id"
                else oss."service_room/id"
            end as "service_room/id",
            case
                when oss."exam_room/id" is null then isbr."exam_room/id"
                else oss."exam_room/id"
            end as "exam_room/id",
            oss."categ_id/id",
            oss.type_product_crm,
            oss.list_price,
            oss.price_min,
            oss."currency_id/id",
            oss.is_surgeries,
            oss."surgery_type",
            oss."anesthetist_type",
            oss."uom_id/id",
            oss."uom_id/name",
            oss."uom_so_id/id",
            oss."uom_po_id/id",
            oss.his_service_type,
            oss.level_of_difficult,
            oss.execution_time,
            oss.recovery_time,
            oss.warranty_period,
            oss."uom_guarantee/name",
            oss."note",
            oss.kpi_point,
            oss.kpi_point_num,
            oss.is_no_specialty,
            oss.is_no_phonecall,
            oss.is_input_num,
            case
                when oss."lab_type_ids/id" is null then isbr."lab_type_ids/id"
                else oss."lab_type_ids/id"
            end as "lab_type_ids/id",
            case
                when oss."imaging_type_ids/id" is null then isbr."imaging_type_ids/id"
                else oss."imaging_type_ids/id"
            end as "imaging_type_ids/id",
            oss."ceiling_discount_ids/brand_id/id",
            oss."ceiling_discount_ids/ceiling_discount",
            oss."hướng dẫn sau dịch vụ",
            oss."tính hoa hồng ctv",
            oss.ghi_chu,
            oss.brand
    from
        update_id_new_code oss
    left join lateral (
    select isbr.*
                 from {{ ref('stg_idvs_import_service_brand_rh') }} isbr
                 where isbr.brand = oss."ceiling_discount_ids/brand_id/id"
                 and oss.his_service_type = isbr.his_service_type
                 and (oss.surgery_type = isbr.surgery_type or oss.surgery_type is null or isbr.surgery_type is null or oss.surgery_type <> '' or isbr.surgery_type <> '')
    limit 1
    ) isbr on true
    order by oss.stt
