select
            idds.stt,
            idds.id,
            case
                when idds."default_code cũ" is null then idds."default_code mới"
                else idds."default_code cũ"
            end as  "default_code cũ",
            case
                when idds."default_code mới" is null then idds."default_code cũ"
                else idds."default_code mới"
            end as "default_code mới",
            idds."name",
            idds."service_category/name",
            idds."service_category/id"::text,
            idds."institution/id"::text,
            idds."service_department/id"::text,
            idds."service_room/id"::text,
            idds."exam_room/id",
            idds."categ_id/id",
            idds.type_product_crm,
            cast(idds.list_price as numeric(20,0)) as list_price,
            cast(idds.price_min as numeric(20,0)) as price_min,
            idds."currency_id/id",
            case
                when idds.is_surgeries = '1.0' then 'TRUE'
                when idds.is_surgeries = '0.0' then 'FALSE'
                when idds.is_surgeries = 'True' then 'TRUE'
                when idds.is_surgeries = 'False' then 'FALSE'
                else null
            end is_surgeries,
            idds.surgery_type,
            idds.anesthetist_type,
            idds."uom_id/id"::text,
            idds."uom_id/name"::text,
            idds."uom_so_id/id"::text,
            idds."uom_po_id/id"::text,
            case trim(idds.his_service_type)
                when 'Nha' then 'Odontology'
                when 'Chi phí khác' then 'ChiPhi'
                when 'Spa' then 'Spa'
                when 'Phẫu thuật' then 'Surgery'
                when 'Laser' then 'Laser'
                when 'Chăm sóc sức khỏe' then 'wellness'
                else trim(idds.his_service_type)
            end as his_service_type,
            idds.level_of_difficult::numeric,
            cast(idds.execution_time as numeric(20,0)),
            case
                when idds.recovery_time ilike '%.0%' then replace(idds.recovery_time, '.0','')
                else idds.recovery_time
            end as recovery_time,
            idds.warranty_period::numeric(20,0),
            idds."uom_guarantee/name",
            idds.note,
            idds.kpi_point,
            idds.kpi_point_num,
            case
                when idds.is_no_specialty = '1.0' then true
                when idds.is_no_specialty = '0.0' then false
                else null
            end is_no_specialty,
            case
                when idds.is_no_phonecall = '1.0' then true
                when idds.is_no_phonecall = '0.0' then false
                else null
            end is_no_phonecall,
            case
                when idds.is_input_num = '1.0' then true
                when idds.is_input_num = '0.0' then false
                else null
            end is_input_num,
            replace(idds."lab_type_ids/id"::text,' ','') as "lab_type_ids/id",
            replace(idds."imaging_type_ids/id"::text,' ','') as "imaging_type_ids/id",
            idds."ceiling_discount_ids/brand_id/id",
            idds."ceiling_discount_ids/ceiling_discount"::numeric * 100 as "ceiling_discount_ids/ceiling_discount",
            idds."hướng dẫn sau dịch vụ",
            idds."tính hoa hồng ctv",
            idds.ghi_chu,
            idds.brand
        from
            {{ ref('stg_idvs_import_danhmuc_dichvu_sci') }} idds
